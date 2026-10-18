# Dry-run a block-design create_project.tcl in plain tclsh: Vivado commands are stubbed,
# every file, include dir and .coe the script names must exist.
# Usage: tclsh vivado_bd_stub.tcl <path>/create_project.tcl   (run it on a scratch copy:
# the script writes its <name>.ready marker next to itself)
set ::missing 0
set ::nfiles 0
set ::cmds {}
proc unknown {args} { lappend ::cmds [lindex $args 0]; return "" }
proc get_projects {args} { return {} }
proc get_parts {args} { return {xczu9eg-ffvb1156-2-e} }
proc get_board_parts {args} { return {xilinx.com:zcu102:part0:3.4} }
proc get_property {name args} {
    if {$name eq "ARCHITECTURE"} { return zynquplus }
    if {$name eq "NAME"} { return [lindex $args end] }
    return ""
}
proc get_bd_intf_pins {args} { return {m_axi S_AXI S01_AXI S00_AXI} }
proc get_files {args} { return [lindex $args end] }
proc check_path {p what} {
    incr ::nfiles
    if {![file exists $p]} { puts "MISSING $what: $p"; incr ::missing }
}
proc add_files {args} {
    foreach f [lindex $args end] { check_path $f file }
}
proc set_property {args} {
    set name [lindex $args 0]
    if {$name eq "include_dirs"} { foreach d [lindex $args 1] { check_path $d incdir } }
    if {$name eq "-dict"} {
        foreach {k v} [lindex $args 1] { if {$k eq "CONFIG.Coe_File"} { check_path $v coe } }
    }
    if {$name in {verilog_define file_type used_in_simulation used_in_synthesis -name}} {
        puts "set_property [lrange $args 0 1] -> [lindex $args end]"
    }
    return ""
}
source [lindex $argv 0]
puts "checked $::nfiles paths, missing $::missing"
