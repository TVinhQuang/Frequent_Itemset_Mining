param(
    [Parameter(Mandatory)][string]$Csv,
    [Parameter(Mandatory)][string]$Png
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms.DataVisualization
Add-Type -AssemblyName System.Drawing
$rows = @(Import-Csv -LiteralPath $Csv)
$full = @($rows | Where-Object sample_pct -eq 100)
$sizes = @($rows | Group-Object sample_pct | Sort-Object { [int]$_.Name })
$grids = @($full | Group-Object minsup_bp | Sort-Object { [int]$_.Name } -Descending)
$middle = @($rows | Where-Object sample_pct -ne 100 | Select-Object -ExpandProperty minsup_bp -Unique)
if ($sizes.Count -ne 5 -or $middle.Count -ne 1 -or $grids.Count -lt 5 -or @($rows | Where-Object status -ne 'PASS').Count) {
    throw 'Provide a completed, matching benchmark results.csv.'
}
$mid = $middle[0]
$culture = [Globalization.CultureInfo]::InvariantCulture
function Median($group, $field) {
    $numbers = @($group | ForEach-Object { [double]::Parse($_.$field, $culture) } | Sort-Object)
    if ($numbers.Count -ne 3) { throw "Expected three observations for $field" }
    return $numbers[1]
}

$chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
$chart.Width = 1600
$chart.Height = 1000
$chart.BackColor = 'White'
$font = New-Object Drawing.Font('Segoe UI', 11)
$strong = New-Object Drawing.Font('Segoe UI', 13, [Drawing.FontStyle]::Bold)
$palette = [ordered]@{ scan = '#235789'; hash_tree = '#CE651B'; spmf = '#067766' }
$names = @{ scan = 'Julia scan'; hash_tree = 'Julia hash-tree'; spmf = 'SPMF Apriori' }

function Panel($id, $x, $y, $title, $xTitle, $yTitle) {
    $area = $chart.ChartAreas.Add($id)
    $area.Position = New-Object System.Windows.Forms.DataVisualization.Charting.ElementPosition($x, $y, 47, 35)
    $area.AxisX.Title = $xTitle
    $area.AxisY.Title = $yTitle
    foreach ($axis in @($area.AxisX, $area.AxisY)) {
        $axis.TitleFont = $font
        $axis.LabelStyle.Font = $font
        $axis.MajorGrid.LineColor = [Drawing.ColorTranslator]::FromHtml('#DBE2E5')
        $axis.LineColor = [Drawing.Color]::Gray
        $axis.IsLabelAutoFit = $false
        $axis.LabelStyle.Format = '0.##'
    }
    $area.AxisX.MajorGrid.Enabled = $false
    $caption = $chart.Titles.Add($title)
    $caption.Font = $strong
    $caption.Position = New-Object System.Windows.Forms.DataVisualization.Charting.ElementPosition($x, ($y-4), 47, 4)
    return $area
}

function Curve($area, $key, $style, $legend) {
    $series = $chart.Series.Add("$($area.Name)-$key")
    $series.ChartArea = $area.Name
    $series.ChartType = $style
    $series.Color = [Drawing.ColorTranslator]::FromHtml($palette[$key])
    $series.BorderWidth = 3
    $series.MarkerStyle = 'Circle'
    $series.MarkerSize = 7
    $series.IsVisibleInLegend = $legend
    $series.LegendText = $names[$key]
    return ,$series
}

try {
    $title = $chart.Titles.Add("$($rows[0].dataset)  |  Apriori")
    $title.Font = New-Object Drawing.Font('Segoe UI', 21, [Drawing.FontStyle]::Bold)
    $title.Position = New-Object System.Windows.Forms.DataVisualization.Charting.ElementPosition(0, 0, 100, 6)
    $note = $chart.Titles.Add("Trung vị 3 lượt, mỗi lượt khởi động tiến trình mới.  |  Julia $($rows[0].julia_version) · SPMF $($rows[0].spmf_version)")
    $note.Font = $font
    $note.Position = New-Object System.Windows.Forms.DataVisualization.Charting.ElementPosition(0, 97, 100, 3)
    $legend = $chart.Legends.Add('engines')
    $legend.Font = $font
    $legend.LegendStyle = 'Row'
    $legend.Position = New-Object System.Windows.Forms.DataVisualization.Charting.ElementPosition(29, 6, 45, 4)
    $time = Panel 'time' 2 16 'Thời gian theo minsup · toàn bộ dữ liệu' 'Minsup (%)' 'Thời gian tiến trình (giây)'
    $count = Panel 'count' 51 16 'Số tập phổ biến · ba bản khớp hoàn toàn' 'Minsup (%)' 'Số tập phổ biến'
    $scale = Panel 'scale' 2 62 "Thời gian theo cỡ mẫu · minsup $([int]$mid/100)%" 'Số giao dịch (nghìn)' 'Thời gian tiến trình (giây)'
    $ram = Panel 'ram' 51 62 "RAM đỉnh · toàn bộ dữ liệu · minsup $([int]$mid/100)%" '' 'Working set / RSS (MiB)'
    $ticks = @($grids | ForEach-Object { [int]$_.Name/100 })
    $pad = ($ticks[0]-$ticks[-1])*0.04
    foreach ($area in @($time,$count)) {
        $area.AxisX.Minimum = [Math]::Max(0,$ticks[-1]-$pad)
        $area.AxisX.Maximum = $ticks[0]+$pad
        $area.AxisX.IsReversed = $true
        foreach ($tick in $ticks) {
            [void]$area.AxisX.CustomLabels.Add($tick-$pad, $tick+$pad, $tick.ToString('0.##',$culture))
        }
    }
    $ram.AxisX.Minimum = 0.5
    $ram.AxisX.Maximum = 3.5
    $ram.AxisX.Interval = 1
    $scale.AxisX.Minimum = 0
    $scale.AxisX.Maximum = [int]$full[0].transactions / 1000 * 1.08
    foreach ($s in $sizes) {
        $position = [int]$s.Group[0].transactions / 1000
        $half = $scale.AxisX.Maximum / 20
        [void]$scale.AxisX.CustomLabels.Add($position-$half, $position+$half, $position.ToString('0.##', $culture))
    }
    $common = Curve $count 'spmf' 'Line' $false
    foreach ($g in $grids) { [void]$common.Points.AddXY(([int]$g.Name/100), [int]$g.Group[0].spmf_itemsets) }
    $atMid = @($full | Where-Object minsup_bp -eq $mid)
    $bars = Curve $ram 'spmf' 'Column' $false
    $i = 0
    foreach ($key in $palette.Keys) {
        $a = Curve $time $key 'Line' $true
        $b = Curve $scale $key 'Line' $false
        foreach ($g in $grids) {
            [void]$a.Points.AddXY(([int]$g.Name/100), ((Median $g.Group "${key}_wall_ms")/1000))
        }
        foreach ($s in $sizes) {
            $g = @($s.Group | Where-Object minsup_bp -eq $mid)
            [void]$b.Points.AddXY(([int]$g[0].transactions/1000), ((Median $g "${key}_wall_ms")/1000))
        }
        $i++
        $mib = Median $atMid "${key}_peak_mib"
        $index = $bars.Points.AddXY($i, $mib)
        $point = $bars.Points[$index]
        $point.Color = [Drawing.ColorTranslator]::FromHtml($palette[$key])
        $point.AxisLabel = $names[$key]
        [void]$ram.AxisX.CustomLabels.Add($i-0.45, $i+0.45, $names[$key])
        $point.Label = $mib.ToString('0.0', $culture)
        $point.Font = $font
    }
    $chart.SaveImage([IO.Path]::GetFullPath($Png), 'Png')
} finally {
    $chart.Dispose()
    $font.Dispose()
    $strong.Dispose()
}
