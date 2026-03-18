// Orbit Script for kOS

clearScreen.

// THIS SCRIPT ONLY WORKS FOR PROGRADE ORBITS
// FOR RETROGRADE ORBITS, FIDDLE WITH THE AZIMUTH CALCULATOR.

// Parameters
parameter req_inclination is ship:latitude.
parameter apo_exe is 83000.
set per_exe to apo_exe - 2000.
lock shp_periapsis to ship:periapsis.

if (req_inclination > 35){
    set rckt_hdg to (azimth_lh(req_inclination)-5).
}
else{
    set rckt_hdg to (azimth_lh(req_inclination)-2).
}


print "Launch Azimuth is " + round(rckt_hdg, 2). 

set rckt_pch to 90.

lock obt_inc to orbit:inclination.
set cmp_inc to req_inclination.
set lck_hdg to 0.

//WHEN COMMANDS
    
    when (abs(obt_inc-cmp_inc)<0.05) then{
        lock steering to heading(prog_hdn_calc(), rckt_pch).
        set lck_hdg to 1.
        print " ".
        print "Dynamic Heading : Prograde".
    }

    when (prograde:vector:mag > 3700) then{
        lock throttle to thrtl_ctrl(0.3).
        when (prograde:vector:mag > 3770) then{
            lock throttle to thrtl_ctrl(0.1).
        }
    }

    when ship:altitude > 55000 then{
        set ag5 to true.
        wait 1.
        set ag5 to false.
    }
//THEN

// MAIN

    //Launch
    wait 2.

    stage.
    set throtl_ct to 0.
    print " ".
    print "Initiating Launch Sequence".

    until throtl_ct > 0.9{
        set throtl_ct to throtl_ct + 0.1.
        lock throttle to throtl_ct.
        wait 0.1.
    }
    
    stage.
    print "Steering lock : H -> 0; P -> 90".
    lock steering to heading(0,90).

    //Ascent Turn Initiation

    print " ".
    print "Initializing Parameters".

    wait until ship:altitude > 500.
    if(lck_hdg > 0){
        lock steering to heading(prog_hdn_calc(),rckt_pch).
    }
    else{
        lock steering to heading(rckt_hdg,rckt_pch).
    }
    print "Steering lock : H -> " + round(rckt_hdg, 2) + "; P -> "+ round(rckt_pch, 2).
    lock throttle to thrtl_ctrl(2.2).
    print "Throttle lock : TWR -> 2.2".
    set RCS to true.
    print "RCS SET : TRUE".

    set alt_dif to 400.
    set alt_rot to 2000.
    lock alt_ref to ship:altitude.

    wait until ship:altitude > alt_rot.

    print " ".
    print "Initiating Ascent Turn".
    print "Dynamic Pitch".

    set pitch_counter to 90.
    until pitch_counter < 46{
        wait until alt_ref - alt_rot > alt_dif.
        set alt_rot to alt_rot + alt_dif.
        set pitch_counter to pitch_counter - 1.
        set rckt_pch to pitch_counter.
        if(lck_hdg > 0){
            set rckt_hdg to prog_hdn_calc().
        }
    }

    //Ascent Turn Finalization

    print " ".
    print "Finalizing Ascent Turn".
    set err_apo to 0.
    set crt_apo to 60.
    set correct_power to 0.1.
    set correct_speed to 0.05.      // this is effectively seconds

        until (ship:apoapsis > apo_exe){
            set eta_apo to eta:apoapsis.
            set err_apo to crt_apo - eta_apo.
            set correction_pitch to err_apo * correct_power.
            print "Pre-Fix: " + pitch_counter.

            set pitch_counter to pitch_counter + correction_pitch.

            print "Post-Fix: " + pitch_counter.
            if (pitch_counter > 45){
                set pitch_counter to 45.
            }
            if (pitch_counter < 10){
                set pitch_counter to 10.
            }
            print "Apl-Fix: " + pitch_counter.

            set rckt_pch to pitch_counter.
            wait correct_speed. 
        }

    //Horizontal Burn

    print " ".
    print "Initiating Horizontal Burn".
    print "Pitch Lock : P -> -1".
    print "Throttle lock : TWR -> 1.4".

    set rckt_pch to -1.
    lock throttle to thrtl_ctrl(1.4).

    //COARSE Circularisation

    wait until eta:apoapsis < 1.2.
    set CIRC_PID to pidLoop(8,0.02,3,-5,75).
    set CIRC_PID:setpoint to 1.
    
    print " ".
    print "Initiating Circularization Burn.".
    print "Throttle lock : TWR -> 1.4".
    print "Dynamic Pitch".
    lock throttle to thrtl_ctrl(0.9).
    until ship:velocity:orbit:mag > 3670{
        set rckt_pch to CIRC_PID:update(time:seconds, eta_ap_fix()).
        wait 0.
    }

    //FINE Circularisation

    set CIRC_PID to pidLoop(1,0.02,0.5, 0, 1).
    set CIRC_PID:setpoint to 0.
    set rckt_pch to 1.

    print "Dynamic Throttle".
    set throttle_ctrl_pid to thrtl_ctrl(0.9).
    lock throttle to throttle_ctrl_pid.
    until shp_periapsis > per_exe{
        set throttle_ctrl_pid to CIRC_PID:update(time:seconds, ship:verticalspeed).
        wait 0.
    }

    lock throttle to 0.
    unlock steering.
    set SAS to true.
    set RCS to false.

// MAIN END

// Local Functions

local function thrtl_ctrl{
    parameter req_TWR.

    lock shp_mass to ship:mass.
    
    lock shp_thrs to ship:maxthrust.
    lock shp_weig to shp_mass * 9.7.
    
    set shp_TWR to shp_thrs/shp_weig.

    if (shp_TWR=0)
    set shp_TWR to 1.   //Avoid divide by zero during staging

    set thrtl_ctrl_val to req_TWR/shp_TWR.
    return thrtl_ctrl_val.
}

local function prog_hdn_calc{

    //East Vector and Prograde Vector
    set up_vec to ship:up:vector.
    set nrt_vec to ship:north:vector.
    lock est_vec to vCrs(up_vec,nrt_vec).
    lock prog_vec to ship:velocity:orbit.

    //Assigning Values to East and North.
    set nrt_vel to vDot(nrt_vec,prog_vec).
    set est_vel to vDot(est_vec,prog_vec).

    //Getting Heading.
    set hdng_crft to arcTan2(est_vel,nrt_vel).
    return hdng_crft.
}

local function azimth_lh{
    
    parameter req_inc is ship:latitude.

    set iota to req_inc.
    set epsillion to ship:latitude.
    set beta to 90.

    set beta to arcSin(cos(iota)/cos(epsillion)).

    return beta.
}

local function eta_ap_fix{
    set ap_fix to eta:apoapsis.

    if eta:apoapsis > 60
    set ap_fix to eta:apoapsis - orbit:period.

    return ap_fix.
}


//
//  NOTES
//  1. For Launch Azimuth Calculation,
//      Let i = desired orbital inclination, y = Latitude of launch site, b = Launch azimuth
//      Then, cos i = cos y * sin b
//      Then,     b = sin^-1 (cos i / cos y)
//  
//      However, b is the azimuth calculated for a non-spinning body
//      To compensate, the rocket launches -5 deg to the azimuth and locks heading to azimuth when desired inclination is achieved.
//      -- > This will only work with N-E(ascending) Launches, as for S-E(descending) Launches, it would require +5 deg.
//           (Not that I know how the launch window for S-E(descending) works)