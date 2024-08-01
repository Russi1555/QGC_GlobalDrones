
#Se eu entendi bem só preciso rodar isso aqui e eu conecto o Mission Planner COM essa conexão SITL e não o contrário (correto)
#MANDAR O MISSION PLANNER SE CONECTAR COM A PORTA 5602 (acredito que ele cria uma porta de saida na 5600 e uma de entrada na 5601)


#***Necessário pra evitar dor de cabeça relacionada a versão de python***
#from asyncio.windows_events import NULL
import sys
if sys.version_info.major == 3 and sys.version_info.minor >= 10:
    import collections
    from collections.abc import MutableMapping
    setattr(collections, "MutableMapping", MutableMapping)


from dronekit import connect, VehicleMode, ChannelsOverride, Command
import dronekit_sitl
import time
import tkinter as tk
import pymavlink
import lib_controle_drone as control
import queue
from multiprocessing import Process
import subprocess
import os
import os.path


QGC_stdout = ""

def processo_QGC(path):
    global QGC_stdout 
    #path = r'C:\Users\PECCE\Desktop\qgroundcustom\build-qgroundcontrol-Desktop_Qt_5_15_2_MSVC2019_64bit-Debug\staging\QGroundControl.exe'
    QGC_stdout = subprocess.Popen(path,
                                  shell = True, 
                                  stdout=subprocess.PIPE, 
                                  stderr = subprocess.STDOUT )
    while True:
       line = str(QGC_stdout.stdout.readline()).replace("b","").replace("'","")
       #OK. Isso aqui funciona. Da pra fazer um botão no QGroundControl que console.log("ABRA CONTROLE MANUAL") e liga o modo guiado do python por exemplo
       if "TESTE," in line:
           info_extraida = line.split(',')
           print("\n\n" + info_extraida[3] + "\n\n") #dessa forma da pra realizar a conversão binária dos valores do parametro customizado TODO: VER COMO ENVIAR A INFORMAÇÃO CONVERTIDA DE VOLTA
       if "Quit event false\r\n" in line:
           print("CABOU")
           QGC_stdout.kill()
           break

###### CÓDIGO MAIN #####
if __name__ == '__main__': 
    sitl = dronekit_sitl.start_default(-27.593764, -48.541548) #coordenadas da quadra do IFSC
    connection_string = sitl.connection_string()


    print ("Start simulator (SITL)")
    #comando pra conectar com o drone por porta serial
    #connect('COM3', wait_ready=True, baud=57600))
    
    #if not(os.path.exists("arquivo_path.txt")):
    #    print("Input path to QGroundControl.exe: ")
    #    path = input(r"")
    #    arquivo_path = open("arquivo_path.txt",'x+')
    #    arquivo_path.write(path)
    #    arquivo_path.close()
    #arquivo_path = open("arquivo_path.txt",'r')
    #path = arquivo_path.read()
    #arquivo_path.close()
    #QGC = Process(target=processo_QGC, args=(path,))
    #QGC.start() 
#
    #
#
    ## Connect to the Vehicle.
    print("Connecting to vehicle on: %s" % (connection_string,))
    vehicle = connect(connection_string, baud=11520, wait_ready=True)
    ##vehicle = connect("com3", baud=11520, wait_ready=True)
    cmds = vehicle.commands

    def enable_geofence():
        # Enable geofence
        vehicle.parameters['FENCE_ENABLE'] = 1
        # Set fence type (e.g., circular or polygon)
        vehicle.parameters['FENCE_TYPE'] = 3  # 3 is for polygonal fences
        # Set fence action (e.g., RTL, LOITER)
        vehicle.parameters['FENCE_ACTION'] = 1  # 1 is RTL (Return to Launch)
        vehicle.parameters['FENCE_RADIUS'] = 30

        print("Geofence enabled")

    enable_geofence()
    fence_points = [
        (-27.593764, -48.541548, 50),  # Point 1
        (-27.594000, -48.542000, 50),  # Point 2
        # Add more points as needed
    ]

    def upload_fence():
        # Clear existing mission items
        cmds = vehicle.commands
        cmds.clear()

        # Add fence points
        for i, (lat, lon, alt) in enumerate(fence_points):
            cmds.add(
                Command(
                    0, 0, 0,
                    mavutil.mavlink.MAV_FRAME_GLOBAL_RELATIVE_ALT,
                    mavutil.mavlink.MAV_CMD_NAV_FENCE_POLYGON_VERTEX_INCLUSION,
                    0, 0, 0, 0, 0, 0,
                    lat, lon, alt
                )
            )

    # Upload to vehicle
    cmds.upload()
    print("Fence uploaded successfully")
    
    cmds.download()
    cmds.wait_ready()

    gnd_speed = 10
    fila_comandos = queue.Queue(maxsize=10) #estrutura de fila garante que o drone não vai seguir uma quantidade de comandos imensa que pode leva-lo a uma situação perigosa
    vehicle.initialize
#
    #time.sleep(10)
#
    def key(evento):
        global gnd_speed
        global fila_comandos
    
        print(evento.keysym)
        if evento.keysym == "Up":
            if  fila_comandos.full():
                pass
            else:
                print("ENQUEUE UP")
                fila_comandos.put("up")

        elif evento.keysym == "Down":
            if fila_comandos.full():
                pass
            else:
                fila_comandos.put("down")

        elif evento.keysym == "Right":
            if fila_comandos.full():
                pass
            else:
                fila_comandos.put("right")
        elif evento.keysym == "Left":
            if fila_comandos.full():
                pass
            else:
                fila_comandos.put("left")

        elif evento.keysym == "plus": #Controle de velocidade no + do keypad
            if gnd_speed >= 1 and gnd_speed < 12:
                gnd_speed +=1
            elif gnd_speed > 0 and gnd_speed < 1: #movimentos precisos
                gnd_speed += 0.1
            print(str(gnd_speed))
            time.sleep(1)

        elif evento.keysym == "minus": #Controle de velocidade no - do keypad
            if gnd_speed > 1 :
                gnd_speed -=1
            elif gnd_speed > 0.2 and gnd_speed <= 1: #movimentos precisos
                gnd_speed -= 0.1
            print(str(gnd_speed))
            time.sleep(1)

        elif evento.keysym == "e" or evento.keysym == "E":
            print("TESTE e")
            if fila_comandos.full():
                pass
            else:
                fila_comandos.put("e")
            time.sleep(1)

        elif evento.keysym == "q" or evento.keysym == "Q":
            print("TESTE q")
            if fila_comandos.full():
                pass
            else:
                fila_comandos.put("q")
            time.sleep(1)

        elif evento.keysym == 'bracketleft':
            if fila_comandos.full():
                pass
            else:
                fila_comandos.put("[")
            time.sleep(1)
    
        elif evento.keysym == 'bracketright':
            if fila_comandos.full():
                pass
            else:
                fila_comandos.put("]")
            time.sleep(1)

        else:
            pass
        
        
    root = tk.Tk()
    root.geometry("600x400+300+300")
    lbl= tk.Label(root, text="Instruções", fg='black', font=("Helvetica", 24))
    lbl2 = tk.Label(root, text=" -> ←↑→↓ : Movimenta o drone", fg='black', font=("Helvetica", 16))
    lbl3 = tk.Label(root, text=" -> + - : Aumenta/Reduz velocidade", fg='black', font=("Helvetica", 16))
    lbl4 = tk.Label(root, text=" -> [ ] : Aumenta/Reduz altitude em 1m", fg='black', font=("Helvetica", 16))
    lbl5 = tk.Label(root, text=" -> e q : Rotaciona drone em +/- 10°", fg='black', font=("Helvetica", 16))
    lbl.place(x=0, y=0)
    lbl2.place(x=0, y =48)
    lbl3.place(x=0, y=78)
    lbl4.place(x=0, y=108)
    lbl5.place(x=0, y=138)
    root.attributes('-topmost',True)


    #this creates a new label to the GUI

    control.arm_and_takeoff(vehicle, 3)
    while True:
        root.bind_all("<Key>", key)
        #if not((QGC.is_alive())):
         #   quit()
        if not(fila_comandos.empty()):
            print("TESTE2")
            command = fila_comandos.get()
            if command == "up":
                control.set_velocity_body(vehicle, gnd_speed, 0, 0)
                time.sleep(0.5)
            elif command == "down":
                control.set_velocity_body(vehicle, -gnd_speed, 0, 0)
                time.sleep(0.5)
            elif command == "right":
                control.set_velocity_body(vehicle, 0, gnd_speed, 0)
                time.sleep(0.5)
            elif command == "left":
                control.set_velocity_body(vehicle, 0, -gnd_speed, 0)
                time.sleep(0.5)
            elif command == 'e':
                control.rotate(vehicle,0,0,10) #(pitch, roll, yaw)
                time.sleep(0.5)
            elif command == 'q':
                control.rotate(vehicle,0,0,-10) #(pitch, roll, yaw)
                time.sleep(0.5)
            elif command == '[':
                control.set_velocity_body(vehicle, 0, 0, -0.5)
            elif command == ']':
                control.set_velocity_body(vehicle, 0, 0, 0.5)
            

        root.update_idletasks()
        root.update()


    # Get some vehicle attributes (state)

    # Close vehicle object before exiting script
    vehicle.close()

    # Shut down simulator
    sitl.stop()
    print("Completed")
    QGC.join()
    

