//Land on a Celestial Body -> No Atmos.
//Working on a targetted landing script, Currently not targetted. May land on a rock. Asthetically displeasnig.

set ship_state to "o".

when (ship:velocity:orbit:mag < 400) 
and  (alt:radar > 800) 
and  (ship:periapsis < 0) 
then {set ship_state to "d".}

when (alt:radar < 800)          
then {set ship_state to "l".}

when (alt:radar < 10)           
then {set ship_state to "fl".}

when (ship:status = "LANDED")   
then {set ship_state to "end".}

// --- Initializing Variables --------------------------------------------------

lock ship_altitude  to alt:radar.
lock ship_vspeed    to ship:verticalspeed.
lock ship_facing    to ship:facing:vector.
lock retrograde_vector_orbit to ship:retrograde:vector.

set max_down_speed_descent to 75.

// --- Basic Functions ---------------------------------------------------------

function clamp_values 
{
    parameter clamp_value.
    parameter value_1.
    parameter value_2.

    if clamp_value < value_1 {set clamp_value to value_1.}
    if clamp_value > value_2 {set clamp_value to value_2.}
    return clamp_value.
}

// -----------------------------------------------------------------------------

function get_throttle_for_twr 
{
    parameter req_twr.

    local mass_ship to ship:mass.
    local thrust    to ship:maxthrust.
    local weight    to mass_ship * 9.7.

    if thrust <= 0 { return 1. }

    local twr to thrust / weight.
    if twr <= 0 { return 1. }

    local t to req_twr / twr.

    return clamp_values(t, 0, 1).
}

// -----------------------------------------------------------------------------

function get_vspeed_setpoint
{
    set alt_ship to ship:altitude.

    if ship_state = "d"{return -(min(max_down_speed_descent, sqrt(alt_ship))).}
    if ship_state = "l"{return -sqrt(ship_altitude).}
    if ship_state = "fl"{return (-sqrt(ship_altitude)/20).}
}



// --- STATE CONTROL -----------------------------------------------------------

function orbit_state
{
    clearScreen.

    print " --- STATE: IN ORBIT --- ".
    print " Locking to Retrograde.".
    lock steering to Retrograde.
    until abs(vAng(ship_facing, retrograde_vector_orbit)) < 0.5
    {
        print " Facing Retrograde: " + round(abs(vAng(ship_facing, retrograde_vector_orbit))) at (0,2).
    }
    print " Starting Deorbit Burn.       " at (0,2).

    // --- De-Orbit Burn ---
    until (ship_state = "d" or ship_state = "l")
    {
        lock throttle to get_throttle_for_twr(0.5).
    }
}

// -----------------------------------------------------------------------------

function dl_state
{
    clearScreen.

    wait until ship_altitude < 8000.

    print " --- STATE: DESCENT --- ".

    lock steering to srfRetrograde.
    lock vspeed_target to get_vspeed_setpoint().
    set throttle_ctrl to 0.
    lock throttle to throttle_ctrl.
    set vspeed_thrt to pidLoop(0.08, 0.002, 0.02, 0, 1).

    wait until ship:verticalspeed < vspeed_target.
    until ship_state = "end"
    {
        set vspeed_thrt:setpoint to vspeed_target.
        set throttle_ctrl to vspeed_thrt:update(time:seconds, ship_vspeed).

        print " Target Velocity  -> " + round(vspeed_target,2) at (0,2).
        print " Current Velocity -> " + round(ship_vspeed,2) at (0,3).
    }
}

// -----------------------------------------------------------------------------

function stop
{
    clearScreen.
    print("Landed.").
    lock    throttle to 0.
    unlock  steering.
    set     SAS to true.
}


// --- MAIN PROGRAM ------------------------------------------------------------


orbit_state().

dl_state().

stop().
