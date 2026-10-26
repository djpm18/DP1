# ModelSim/Questa: vsim -c -do "do Simulation/run_Baseline.do"
# Run from the project root or Simulation; captures a unique transcript.
onerror {quit -force -code 1}
onbreak {quit -force -code 1}

# ModelSim's do macro does not reliably set info script. On Windows, use the
# native working directory: this version's Tcl pwd/normalize can corrupt paths.
if {$tcl_platform(platform) eq "windows"} {
    set launch_dir [string trim [exec cmd.exe /c cd]]
} else {
    set launch_dir [pwd]
}
if {[file exists [file join $launch_dir Simulation TBAdderBaseline.vhd]]} {
    set project_dir $launch_dir
} elseif {[file exists [file join $launch_dir TBAdderBaseline.vhd]]} {
    set project_dir [file dirname $launch_dir]
} else {
    puts stderr "Run this script from the project root or Simulation directory."
    quit -force -code 1
}
cd [file join $project_dir Simulation]
set output_dir [file join $project_dir Documentation OutputFiles]
file mkdir $output_dir
transcript file [file join $output_dir AdderBaseline.transcript.txt]
transcript on

if {![file exists modelsim.ini]} {
    vmap -c
}
vlib Work
vmap work Work

vcom -2008 -work work [file join $project_dir SourceCode Baseline.vhd]
vcom -2008 -work work [file join $project_dir SourceCode RippleAdder.vhd]
vcom -2008 -work work [file join $project_dir SourceCode CondSum.vhd]
vcom -2008 -work work TBAdderBaseline.vhd

vsim -voptargs=+acc work.TBAdderBaseline(test)
log -r /*
add wave -radix unsigned sim:/TBAdderBaseline/MeasurementIndex
add wave -radix unsigned sim:/TBAdderBaseline/FailureCount
add wave -radix hexadecimal sim:/TBAdderBaseline/A sim:/TBAdderBaseline/B
add wave sim:/TBAdderBaseline/Cin
add wave -radix hexadecimal sim:/TBAdderBaseline/ExpectedS sim:/TBAdderBaseline/S
add wave sim:/TBAdderBaseline/ExpectedCout sim:/TBAdderBaseline/Cout
add wave sim:/TBAdderBaseline/ExpectedOvfl sim:/TBAdderBaseline/Ovfl
add wave sim:/TBAdderBaseline/TestDone
run -all

if {![string equal -nocase [examine sim:/TBAdderBaseline/TestDone] true]} {
    error "Simulation ended before the last test vector."
}
if {[examine -radix decimal sim:/TBAdderBaseline/FailureCount] != 0} {
    error "Adder verification failed."
}
transcript off
quit -force -code 0
