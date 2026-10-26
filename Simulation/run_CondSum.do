# ModelSim/Questa: vsim -c -do "do Simulation/run_CondSum.do"
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
if {[file exists [file join $launch_dir Simulation TBAdderCondSum.vhd]]} {
    set project_dir $launch_dir
} elseif {[file exists [file join $launch_dir TBAdderCondSum.vhd]]} {
    set project_dir [file dirname $launch_dir]
} else {
    puts stderr "Run this script from the project root or Simulation directory."
    quit -force -code 1
}
cd [file join $project_dir Simulation]
set output_dir [file join $project_dir Documentation OutputFiles]
file mkdir $output_dir
transcript file [file join $output_dir AdderCondSum.transcript.txt]
transcript on

if {![file exists modelsim.ini]} {
    vmap -c
}
vlib Work
vmap work Work

vcom -2008 -work work [file join $project_dir SourceCode Baseline.vhd]
vcom -2008 -work work [file join $project_dir SourceCode RippleAdder.vhd]
vcom -2008 -work work [file join $project_dir SourceCode CondSum.vhd]
vcom -2008 -work work TBAdderCondSum.vhd

vsim -voptargs=+acc work.TBAdderCondSum(test)
log -r /*
add wave -radix unsigned sim:/TBAdderCondSum/MeasurementIndex
add wave -radix unsigned sim:/TBAdderCondSum/FailureCount
add wave -radix hexadecimal sim:/TBAdderCondSum/A sim:/TBAdderCondSum/B
add wave sim:/TBAdderCondSum/Cin
add wave -radix hexadecimal sim:/TBAdderCondSum/ExpectedS sim:/TBAdderCondSum/S
add wave sim:/TBAdderCondSum/ExpectedCout sim:/TBAdderCondSum/Cout
add wave sim:/TBAdderCondSum/ExpectedOvfl sim:/TBAdderCondSum/Ovfl
add wave sim:/TBAdderCondSum/TestDone
run -all

if {![string equal -nocase [examine sim:/TBAdderCondSum/TestDone] true]} {
    error "Simulation ended before the last test vector."
}
if {[examine -radix decimal sim:/TBAdderCondSum/FailureCount] != 0} {
    error "Adder verification failed."
}
transcript off
quit -force -code 0
