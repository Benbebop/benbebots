import time
from python_aternos import Client

print("starting server, please wait")

aternos = Client.from_credentials("sexgaming_", "sexisbadjk")

servs = aternos.list_servers()

myserv = servs[0]

myserv.start()

print("start signal sent, waiting for setup to complete")

while myserv.status != "Offline":
    time.sleep(10)

print("aternos server online")