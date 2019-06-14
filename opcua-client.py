#!/usr/bin/python3

import time
import asyncio
import logging
import struct
import sys
import signal
from kafka import KafkaProducer
from kafka.admin import KafkaAdminClient,NewTopic

from asyncua import Client
#from asyncua.ua import uaprotocol_auto

logging.basicConfig(level=logging.WARNING)
_logger = logging.getLogger('asyncua')
producer = KafkaProducer(bootstrap_servers='localhost:9092')
admin = KafkaAdminClient(bootstrap_servers='localhost:9092')

subs_timeout = 300
address = "192.168.10.2"
killtime = 60

if len(sys.argv) > 1 :
    subs_timeout = int(sys.argv[1])
if len(sys.argv) > 2 :
    address = str(sys.argv[2])
if len(sys.argv) > 3 :
    killtime = int(sys.argv[3])

assert (int(subs_timeout) > 0),"timeout less than absolute zero!"
assert (len(address) > 0 ), "address not valid"
assert (int(killtime) > 0 ), "killtime not valid"

class SubHandler(object):

    def __init__(self,log,nodemap):
        self.log = log
        self.m = nodemap

    def datachange_notification(self, node, val, data):

        now = time.time()
        delay = now - val

        self.log.info("%s: New data change event: %s, %f", time.ctime(now), node, delay)
        producer.send(self.m[node.nodeid], bytearray(struct.pack("f",time.time()-val)) )


    def event_notification(self, event):
        _logger.info("New event", event)

async def timer():
    global stop
    await asyncio.sleep(killtime)
    stop = 1

async def run():
    global stop
    stop = 0
    url = 'opc.tcp://' + address + ':4840/freeopcua/server/'

    try:
        async with Client(url=url) as client:
            def interruptHandler(signal, frame):
                global stop
                stop = 1
                print("Interrupt (ID: {}) has been caught. Cleaning up...".format(signal))

            signal.signal(signal.SIGINT, interruptHandler)
            root = client.get_root_node()
            _logger.info("Root node is: %r", root)
            objects = client.get_objects_node()
            _logger.info("Objects node is: %r", objects)
            sensor = await objects.get_child("2:MyObject")

            childs = await sensor.get_children()
            _logger.info("Children of sensor are: %r", childs)

            nodemap  = {}

            subs = childs
            for i in subs:
                name = await i.get_description();
                nodemap[i.nodeid] = name.Text;

            sub = await client.create_subscription(subs_timeout,
                    SubHandler(_logger,nodemap))

            await sub.subscribe_data_change(subs)
            loop = asyncio.get_event_loop()
            loop.create_task(timer())
            
            while True:
                await asyncio.sleep(0.5)
                if not sub:
                    raise Exception("sub died")
                if not client:
                    raise Exception("client died")
                if stop:
                    await sub.delete()
                    break

    except Exception:
        _logger.exception('error')
        cfile.close()

if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.set_debug(True)
    loop.run_until_complete(run())

