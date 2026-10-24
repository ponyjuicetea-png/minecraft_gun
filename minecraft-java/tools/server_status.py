"""Query Minecraft Java's public server-list protocol without account credentials."""
import argparse
import json
import socket
import struct


def varint(value):
    data=bytearray()
    while True:
        part=value & 0x7f; value >>= 7
        data.append(part | (0x80 if value else 0))
        if not value: return bytes(data)


def read_exact(stream,count):
    data=bytearray()
    while len(data)<count:
        chunk=stream.recv(count-len(data))
        if not chunk: raise ConnectionError('Server closed the status connection')
        data.extend(chunk)
    return bytes(data)


def read_varint(stream):
    value=0
    for position in range(5):
        part=read_exact(stream,1)[0]
        value |= (part & 0x7f) << (7*position)
        if not part & 0x80: return value
    raise ValueError('Invalid status VarInt')


def status(host='127.0.0.1',port=25565):
    address=host.encode('utf-8')
    handshake=b'\x00'+varint(763)+varint(len(address))+address+struct.pack('>H',port)+b'\x01'
    with socket.create_connection((host,port),timeout=3) as stream:
        stream.sendall(varint(len(handshake))+handshake+b'\x01\x00')
        length=read_varint(stream)
        if length>2*1024*1024: raise ValueError('Status packet is too large')
        if read_varint(stream)!=0: raise ValueError('Expected a status response')
        json_size=read_varint(stream)
        if json_size>length: raise ValueError('Invalid status payload length')
        return json.loads(read_exact(stream,json_size).decode('utf-8'))


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--host',default='127.0.0.1')
    parser.add_argument('--port',type=int,default=25565)
    args=parser.parse_args()
    print(json.dumps(status(args.host,args.port),indent=2,ensure_ascii=False))
