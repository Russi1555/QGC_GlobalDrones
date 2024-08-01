#***Necessário pra evitar dor de cabeça relacionada a versão de python***
import sys
if sys.version_info.major == 3 and sys.version_info.minor >= 10:
    import collections
    setattr(collections, "MutableMapping", collections.abc.MutableMapping)
from dronekit import connect, VehicleMode
import dronekit_sitl
import time
import tkinter as tk
import pymavlink


def arm_and_takeoff(vehicle, altitude):
    while not vehicle.is_armable:
        print("Aguardando poder armar o veiculo")
        time.sleep(1)
    
    time.sleep(5)
    print("armando motores")
    vehicle.mode = VehicleMode("LOITER")
    set_guided_mode(vehicle)
    print("foi?")
    #vehicle.armed = True
    #print(vehicle.mode.name)
    #vehicle.mode = VehicleMode('GUIDED')
    
   # while(vehicle.mode.name != "GUIDED"):
    #    vehicle.mode = VehicleMode('GUIDED')
        
    #time.sleep(1)  
    #vehicle.armed = True
    #time.sleep(1)

    #print("levantando voo")
    #vehicle.mode = VehicleMode("GUIDED")
    #vehicle.armed = True
    

    while True:
        v_alt = vehicle.location.global_relative_frame.alt
        print(">>> Altitude atual :  " + str(v_alt))
        if vehicle.mode.name != "GUIDED":
            print("alterando para modo de voo guiado")
            vehicle.mode = VehicleMode("GUIDED")
        if not(vehicle.armed):
            print("armando motores")
            vehicle.armed = True
        else:
            print("levantando voo")
            vehicle.simple_takeoff(altitude)
        if v_alt >= altitude - 1: 
            print("Altitude desejada atingida")
            break
        time.sleep(1)

def set_velocity_body(vehicle, vx , vy , vz):
    #vz é positivo quando esta indo em direção ao chão

    msg = vehicle.message_factory.set_position_target_local_ned_encode(
            0,
            0, 0,
            pymavlink.mavutil.mavlink.MAV_FRAME_BODY_NED,
            0b0000111111000111, #-- BITMASK -> #atualmente não tem suporte pra controlar o drone através de aceleração.
            0, 0, 0,        #-- POSITION
            vx, vy, vz,     #-- VELOCITY
            0, 0, 0,        #-- ACCELERATIONS
            0, 0)
    vehicle.send_mavlink(msg)
    vehicle.flush()

    

def rotate(vehicle, pitch, roll, yaw): #retirado de dronekit __init__.py TALVEZ NÃO FUNCIONA. TA BIZARRO

    if yaw>0:
        # create the CONDITION_YAW command using command_long_encode()
        msg = vehicle.message_factory.command_long_encode(
            0, 0,    # target system, target component
            pymavlink.mavutil.mavlink.MAV_CMD_CONDITION_YAW, #command
            0, #confirmation
            yaw,    # param 1, yaw in degrees
            0.1,          # param 2, yaw speed deg/s
            1,          # param 3, direction -1 ccw, 1 cw
            1, # param 4, relative offset 1, absolute angle 0
            0, 0, 0)    # param 5 ~ 7 not used
        # send command to vehicle
    else:
        msg = vehicle.message_factory.command_long_encode(
            0, 0,    # target system, target component
            pymavlink.mavutil.mavlink.MAV_CMD_CONDITION_YAW, #command
            0, #confirmation
            abs(yaw),    # param 1, yaw in degrees
            0.1,          # param 2, yaw speed deg/s
            -1,          # param 3, direction -1 ccw, 1 cw
            1, # param 4, relative offset 1, absolute angle 0
            0, 0, 0)    # param 5 ~ 7 not used
        # send command to vehicle

    vehicle.send_mavlink(msg)
    vehicle.flush()

def set_guided_mode(vehicle): # https://github.com/OpenSolo/mavlink-solo/blob/4060b70d7cd0a7ffe66f45fcd041e6f9af308852/message_definitions/v1.0/common.xml#L1692
    msg = vehicle.message_factory.command_long_encode(
        0, 0, pymavlink.mavutil.mavlink.MAV_CMD_DO_SET_MODE, 0, 4, 4, 4, 0, 0, 0, 0
        )

    


    vehicle.send_mavlink(msg)
    vehicle.flush()


    