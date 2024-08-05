import asyncio
import websockets
import threading
import subprocess
import os
import sys
from datetime import datetime
from multiprocessing import Process
import re
from report_generator import report_generator


clients = set()

# Example: Setting LD_LIBRARY_PATH for Qt 5.15.2
os.environ['LD_LIBRARY_PATH'] = '/home/russi/Qt/5.15.2/gcc_64/lib'
# Example: Setting QT_PLUGIN_PATH for Qt 5.15.2
os.environ['QT_PLUGIN_PATH'] = '/home/russi/Qt/5.15.2/gcc_64/plugins'

# You can set other environment variables similarly
# os.environ['VAR_NAME'] = 'value'

# Example usage:
print("LD_LIBRARY_PATH:", os.getenv('LD_LIBRARY_PATH'))
print("QT_PLUGIN_PATH:", os.getenv('QT_PLUGIN_PATH'))


def processo_QGC(path=""):
    def DMS_to_DD(coordinate):
        deg, minutes, seconds, direction =  re.split('[°\'"]', coordinate)
        direction = direction.removesuffix(",")
        return float((float(deg) + float(minutes)/60 + float(seconds)/(60*60)) * (-1 if direction in ['W', 'S'] else 1))


    path = r'/home/russi/QtProjects/Estagio/QGroundControl_IFSC/build/Desktop_Qt_5_15_2_GCC_64bit-Release/staging/QGroundControl'
    breaches_num = 0
    QGC_stdout = subprocess.Popen(path,
                                  shell=True, 
                                  stdout=subprocess.PIPE, 
                                  stderr=subprocess.STDOUT)
    max_breach_count = 0
    report_recording = False
    current_GPS_problem = False
    current_RC_problem = False
    current_breach_count = 1
    low_battery = False
    currently_flying = False
    REPORT = [] #lista ordenada cronologicamente de alertas
    #breaches = [] #formato coordenada, horário
    while True:
        line = QGC_stdout.stdout.readline().decode()
        if not line:
            break
        print(line.strip())
        if "TESTE," in line:
            info_extraida = line.split(',')
            print(f"\n\n{info_extraida[3]}\n\n")  # Processes extracted information
        if "COMEÇAR_RELATÓRIO" in line:
            report_recording = True
            current_time = datetime.now().time()
            parse = line.split(" ")
            lat = f'{parse[2]} {parse[3]} {parse[4]} {parse[5]}'
            lon = f'{parse[6]} {parse[7]} {parse[8]} {parse[9]}'
            lat = DMS_to_DD(lat)
            lon = DMS_to_DD(lon)
            report_begin = {"tag": "report_start","time": current_time, "lat": lat, "lon":lon}
            REPORT.append(report_begin)
        if "FINALIZAR_RELATÓRIO" in line:
            report_recording = False
            current_time = datetime.now().time()
            parse = line.split(" ")
            lat = f'{parse[2]} {parse[3]} {parse[4]} {parse[5]}'
            lon = f'{parse[6]} {parse[7]} {parse[8]} {parse[9]}'
            lat = DMS_to_DD(lat)
            lon = DMS_to_DD(lon)
            report_end = {"tag": "report_end","time": current_time, "lat": lat, "lon":lon}
            REPORT.append(report_end)
            print(REPORT)
            report_generator(REPORT)

        

        if report_recording:
            print("REPORT RECORDING")
            if "GPS_LOW_PRECISION" in line and not current_GPS_problem:
                current_GPS_problem=True
                current_time = datetime.now().time()
                parse = line.split(" ")
                #print(parse)
                lat = f'{parse[2]} {parse[3]} {parse[4]} {parse[5]}'
                lon = f'{parse[6]} {parse[7]} {parse[8]} {parse[9]}'
                lat = DMS_to_DD(lat)
                lon = DMS_to_DD(lon)
                print(lat,lon)
                report_gps = {"tag": "GPS_LOW", "time": current_time, "lat": lat, "lon":lon}
                REPORT.append(report_gps)
            if "breach_count" in line: #parse[3] = "numero\n"
                print("BREACH DETECTED1")
                parse = line.split(" ")
                current_breach_count = int(parse[2])
                if current_breach_count > max_breach_count:
                    current_time = datetime.now().time()
                    print("BREACH DETECTED")
                    report_breach = {"tag": "BREACH", "time": current_time, "lat": float(parse[5]), "lon": float(parse[6])}
                    REPORT.append(report_breach)
                    max_breach_count = current_breach_count
                    current_breach_count+=1
    
            print(REPORT)
            
            

        if "Quit event false" in line:
            print("Process ended")
            QGC_stdout.kill()
            break


async def register(websocket):
    clients.add(websocket)
    print("New client connected")
    try:
        await websocket.wait_closed()
    finally:
        clients.remove(websocket)
        print("Client disconnected")
        exit()

async def echo(websocket, path):
    async for message in websocket:
        print(f"Received message: {message}")
        await websocket.send(f"Echo: {message}")

async def main():
    async with websockets.serve(handler, "localhost", 8765):  # Changed to port 8767
        await asyncio.Future()  # run forever

async def handler(websocket, path):
    await register(websocket)
    await echo(websocket, path)

def start_websocket_server():
    asyncio.run(main())

def send_messages():
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    async def send_to_clients():
        while True:
            message = input("Enter message to send to clients: ")
            if clients:  # Check if there are connected clients
                tasks = [asyncio.create_task(client.send(message)) for client in clients]
                await asyncio.wait(tasks)
            else:
                print("No clients connected")

    loop.run_until_complete(send_to_clients())

if __name__ == "__main__":
    # Start QGC subprocess
    QGC = threading.Thread(target=processo_QGC)
    QGC.start() 

    # Start WebSocket server in a separate thread
    server_thread = threading.Thread(target=start_websocket_server)
    server_thread.start()

    # Start send_messages in the main thread
    send_messages()

    # Wait for both threads to complete
    QGC.join()
    server_thread.join()
