# Project settings
set project_name "friscv-system-hw"
set origin_dir [file normalize [file dirname [info script]]/..]
set project_dir "${origin_dir}/${project_name}"
set rtl_dir "${origin_dir}/rtl"
set constraints_dir "${origin_dir}/constraints"
set ip_dir "${origin_dir}/ip"
set bd_dir "${origin_dir}/bd"
set sim_dir "${origin_dir}/sim"

# Device part for PYNQ-Z2
set part "xc7z020clg400-1"

# Close any open project
catch {close_project}

# Create project
puts "Creating project ${project_name} in ${project_dir}..."
create_project ${project_name} ${project_dir} -part ${part} -force

# Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

# Add RTL sources (without copying)
puts "Adding RTL sources from ${rtl_dir}..."
if {[file exists ${rtl_dir}]} {
    set rtl_files [glob -nocomplain ${rtl_dir}/*.v ${rtl_dir}/*.sv]
    if {[llength $rtl_files] > 0} {
        add_files -norecurse -fileset sources_1 $rtl_files
        puts "  Added [llength $rtl_files] RTL file(s)"
    }
}

# Add constraint files (without copying)
if {[file exists ${constraints_dir}]} {
    puts "Adding constraints from ${constraints_dir}..."
    set xdc_files [glob -nocomplain ${constraints_dir}/*.xdc]
    if {[llength $xdc_files] > 0} {
        add_files -norecurse -fileset constrs_1 $xdc_files
        puts "  Added [llength $xdc_files] constraint file(s)"
    }
}

# Add IP cores (without copying)
if {[file exists ${ip_dir}]} {
    puts "Adding IP from ${ip_dir}..."
    foreach ip_xci [glob -nocomplain ${ip_dir}/*/*.xci] {
        add_files -norecurse -fileset sources_1 ${ip_xci}
        puts "  Added IP: [file tail $ip_xci]"
    }
}

# Create and configure block design
set bd_tcl_file "${bd_dir}/design_1/design_1.tcl"
if {[file exists ${bd_tcl_file}]} {
    puts ""
    puts "=========================================="
    puts "Configuring Block Design"
    puts "=========================================="
    puts "Sourcing block design from ${bd_tcl_file}..."
    
    # Source the block design TCL
    source ${bd_tcl_file}
    
    # Get the block design name
    set bd_name [current_bd_design]
    puts "Block design name: ${bd_name}"
    
    # Regenerate layout
    puts "Regenerating block design layout..."
    regenerate_bd_layout
    
    # Save the block design (creates the .bd file)
    puts "Saving block design..."
    save_bd_design
    
    # Now get the .bd file
    set bd_file [get_files ${bd_name}.bd]
    
    # Try to validate, but don't fail if there are errors
    puts "Validating block design..."
    if {[catch {validate_bd_design} validation_result]} {
        puts ""
        puts "WARNING: Block design validation failed:"
        puts "----------------------------------------"
        puts $validation_result
        puts "----------------------------------------"
        puts "Continuing anyway - fix errors in GUI before synthesis"
        puts ""
    } else {
        puts "Block design validated successfully!"
    }
    
    # Generate output products
    puts "Generating output products..."
    if {[catch {generate_target all ${bd_file}} gen_result]} {
        puts "WARNING: Could not generate all output products:"
        puts $gen_result
        puts "Attempting to generate synthesis files only..."
        if {[catch {generate_target {synthesis} ${bd_file}} synth_result]} {
            puts "WARNING: Could not generate synthesis files either:"
            puts $synth_result
        }
    } else {
        puts "Output products generated successfully"
    }
    
    # Create HDL wrapper
    puts "Creating HDL wrapper for block design..."
    if {[catch {
        set wrapper_file [make_wrapper -files ${bd_file} -top]
        add_files -norecurse ${wrapper_file}
    } wrapper_error]} {
        puts "ERROR: Failed to create HDL wrapper:"
        puts $wrapper_error
        puts ""
        puts "This usually means there are design errors that must be fixed."
        puts "Open the project and fix the block design, then try again."
        return -code error "HDL wrapper creation failed"
    }
    
    # Set wrapper as top and lock it
    puts "Setting ${bd_name}_wrapper as top module..."
    set_property top ${bd_name}_wrapper [current_fileset]
    set_property top_auto_set 0 [current_fileset]
    
    # Update compile order
    update_compile_order -fileset sources_1
    
    puts ""
    puts "Block design configuration complete!"
    puts "  Design: ${bd_name}"
    puts "  Wrapper: ${bd_name}_wrapper (set as TOP)"
    puts ""
    
} else {
    puts ""
    puts "WARNING: Block design TCL not found at ${bd_tcl_file}"
    puts ""
    puts "To export your block design:"
    puts "  1. Open your block design in Vivado"
    puts "  2. File -> Export -> Export Block Design"
    puts "  3. Save as: ${bd_tcl_file}"
    puts ""
    puts "Or use Tcl command:"
    puts "  write_bd_tcl ${bd_tcl_file}"
    puts ""
}

# Add simulation sources and create simulation sets
if {[file exists ${sim_dir}]} {
    puts ""
    puts "=========================================="
    puts "Creating Simulation Sets"
    puts "=========================================="
    
    # Find all testbench files
    set sim_files [glob -nocomplain ${sim_dir}/*_tb.v ${sim_dir}/*_tb.sv ${sim_dir}/tb_*.v ${sim_dir}/tb_*.sv]
    
    if {[llength $sim_files] > 0} {
        set first_sim 1
        set first_sim_set ""
        
        foreach sim_file $sim_files {
            # Extract testbench name (without extension)
            set tb_name [file rootname [file tail ${sim_file}]]
            
            # Determine simulation set name
            # Remove tb_ prefix or _tb suffix for cleaner set names
            set sim_set_name ${tb_name}
            if {[string match "tb_*" ${tb_name}]} {
                set sim_set_name [string range ${tb_name} 3 end]
            } elseif {[string match "*_tb" ${tb_name}]} {
                set sim_set_name [string range ${tb_name} 0 end-3]
            }
            set sim_set_name "sim_${sim_set_name}"
            
            # Create simulation set (use sim_1 for first, create new sets for others)
            if {${first_sim}} {
                set sim_set "sim_1"
                set first_sim 0
                set first_sim_set ${sim_set}
                puts "Using default simulation set: ${sim_set} for ${tb_name}"
            } else {
                set sim_set ${sim_set_name}
                puts "Creating simulation set: ${sim_set} for ${tb_name}"
                create_fileset -simset ${sim_set}
            }
            
            # Add simulation file to the set
            add_files -norecurse -fileset ${sim_set} ${sim_file}
            
            # Set this testbench as top for this simulation set
            set_property top ${tb_name} [get_filesets ${sim_set}]
            set_property top_lib xil_defaultlib [get_filesets ${sim_set}]
            
            # Simulation settings
            set_property -name {xsim.simulate.runtime} -value {1000ns} -objects [get_filesets ${sim_set}]
            
            # Check for associated waveform configuration file
            set wcfg_file "${sim_dir}/${tb_name}_behav.wcfg"
            if {[file exists ${wcfg_file}]} {
                add_files -norecurse -fileset ${sim_set} ${wcfg_file}
                set_property xsim.view ${wcfg_file} [get_filesets ${sim_set}]
                puts "  └─ Added waveform config: [file tail ${wcfg_file}]"
            }
            
            puts "  └─ Top module: ${tb_name}"
        }
        
        # Set the first simulation set as active
        if {${first_sim_set} ne ""} {
            current_fileset -simset [get_filesets ${first_sim_set}]
            puts ""
            puts "Active simulation set: ${first_sim_set}"
        }
        
        puts ""
        puts "Created [llength $sim_files] simulation set(s)"
        
    } else {
        puts "No testbench files found in ${sim_dir}"
    }
}

puts ""
puts "=========================================="
puts "Project Created Successfully!"
puts "=========================================="
puts "Location: ${project_dir}/${project_name}.xpr"
puts ""

# Display current top module
set top_module [get_property top [current_fileset]]
puts "Synthesis top module: ${top_module}"

# Display all simulation sets
set sim_sets [get_filesets -filter {FILESET_TYPE == SimulationSrcs}]
if {[llength $sim_sets] > 0} {
    puts ""
    puts "Simulation sets:"
    foreach sim_set $sim_sets {
        set sim_top [get_property top [get_filesets ${sim_set}]]
        set is_active [expr {${sim_set} eq [current_fileset -simset]}]
        if {${is_active}} {
            puts "  * ${sim_set} (top: ${sim_top}) \[ACTIVE\]"
        } else {
            puts "    ${sim_set} (top: ${sim_top})"
        }
    }
}

puts ""
