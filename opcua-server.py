#!/usr/bin/python3
import signal
import asyncio
import copy
import logging
import time
import sys
import csv   
from asyncua import ua, uamethod, Server

refresh = 0.1

if len(sys.argv) > 1:
    nvars = int(sys.argv[1])
else:
    print("insert number of vars")
    sys.exit(1)

if len(sys.argv) > 2:
    refresh = float(sys.argv[2])

assert( float(refresh) > 0 ),"refresh rate not valid"

stop = 0

async def main():
    global stop
    # optional: setup logging
    #logging.basicConfig(level=logging.INFO)
    #logger = logging.getLogger("asyncua.address_space")
    # logger.setLevel(logging.DEBUG)
    #logger = logging.getLogger("asyncua.internal_server")
    # logger.setLevel(logging.DEBUG)
    #logger = logging.getLogger("asyncua.binary_server_asyncio")
    # logger.setLevel(logging.DEBUG)
    #logger = logging.getLogger("asyncua.uaprocessor")
    # logger.setLevel(logging.DEBUG)

    # now setup our server
    server = Server()
    await server.init()
    #server.disable_clock()
    server.set_endpoint("opc.tcp://0.0.0.0:4840/freeopcua/server/")
    server.set_server_name("FreeOpcUa Example Server")

    server.set_security_policy([
                ua.SecurityPolicyType.NoSecurity,
                ua.SecurityPolicyType.Basic256Sha256_SignAndEncrypt,
                ua.SecurityPolicyType.Basic256Sha256_Sign])

    # setup our own namespace
    uri = "http://examples.freeopcua.github.io"
    idx = await server.register_namespace(uri)

    # populating our address space
    myobj = await server.nodes.objects.add_object(idx, "MyObject")

    myvars = []
    count = 0
    for i in range(0,nvars):
        count = count + 1
        myvar = await myobj.add_variable(idx, f"MyVariable{i}", time.time())
        myvars.append(myvar)

    await server.start()
    print("Available loggers are: ", logging.Logger.manager.loggerDict.keys())
    
    fd = open('/tmp/opcua-counting', 'w')
    while True:
        await asyncio.sleep(refresh)
        for i in myvars:
            count = count + 1
            server.set_attribute_value(i.nodeid, ua.DataValue(time.time()))
        if (stop):
            fd.write(str(count))
            fd.close()
            break

    logging.info("Closing server...")
    await server.stop()

def keyboardInterruptHandler(signal, frame):
    global stop
    stop = 1
    print("KeyboardInterrupt (ID: {}) has been caught. Cleaning up...".format(signal))

if __name__ == "__main__":
    signal.signal(signal.SIGINT, keyboardInterruptHandler)
    loop = asyncio.get_event_loop()
    #loop.set_debug(True)
    loop.run_until_complete(main())
