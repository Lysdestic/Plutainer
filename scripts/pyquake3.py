"""
Python Quake 3 Library
http://misc.slowchop.com/misc/wiki/pyquake3
Copyright (C) 2006-2007 Gerald Kaszuba
Updated for Python 3 compatibility.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.
"""

import socket
import re

class Player(object):
    """
    Player class
    """
    def __init__(self, num, name, frags, ping, address=None, bot=-1):
        self.num = num
        self.name = name
        self.frags = frags
        self.ping = ping
        self.address = address
        self.bot = bot

    def __str__(self):
        return self.name

    def __repr__(self):
        return str(self)


class PyQuake3(object):
    """
    PyQuake3 class
    """
    packet_prefix = b'\xff' * 4
    player_reo = re.compile(br'^(\d+) (\d+) "(.*)"')

    rcon_password = None
    port = None
    address = None
    players = None
    values = None

    def __init__(self, server, rcon_password=''):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.set_server(server)
        self.set_rcon_password(rcon_password)

    def set_server(self, server):
        try:
            self.address, self.port = server.split(':')
        except (ValueError, AttributeError):
            raise ValueError('Server address format must be: "address:port"')
        self.port = int(self.port)
        self.sock.connect((self.address, self.port))

    def get_address(self):
        return '%s:%s' % (self.address, self.port)

    def set_rcon_password(self, rcon_password):
        self.rcon_password = rcon_password

    def send_packet(self, data):
        self.sock.send(b'%s%s\n' % (self.packet_prefix, data.encode('utf-8')))

    def recv(self, timeout=1):
        self.sock.settimeout(timeout)
        try:
            return self.sock.recv(8192)
        except socket.error as err:
            raise Exception('Error receiving the packet: %s' % err[1])

    def command(self, cmd, timeout=1, retries=3):
        while retries:
            self.send_packet(cmd)
            try:
                data = self.recv(timeout)
            except Exception:
                data = None
            if data:
                return self.parse_packet(data)
            retries -= 1
        raise Exception('Server response timed out')

    def rcon(self, cmd):
        r_cmd = self.command('rcon "%s" %s' % (self.rcon_password, cmd))
        # The response from the server is now text
        if r_cmd[1] == 'No rconpassword set on the server.\n' or r_cmd[1] == 'Bad rconpassword.\n':
            raise Exception(r_cmd[1][:-1])
        return r_cmd

    def parse_packet(self, data):
        """
        Parse the received packet (as bytes) and return decoded text parts.
        """
        # data is received as raw bytes
        if not data.startswith(self.packet_prefix):
            raise Exception('Malformed packet')

        # Find the first newline character (as bytes)
        first_line_end = data.find(b'\n')
        if first_line_end == -1:
            raise Exception('Malformed packet')

        # Slice the bytes and THEN decode each part into a string.
        # The response type is between the prefix and the first newline.
        response_type = data[len(self.packet_prefix):first_line_end].decode('utf-8', 'ignore')
        
        # The actual data payload is everything after the first newline.
        response_data = data[first_line_end + 1:].decode('utf-8', 'ignore')

        return response_type, response_data

    def parse_status(self, data):
        split = data[1:].split('\\')
        values = dict(zip(split[::2], split[1::2]))
        for var, val in values.items():
            pos = val.find('\n')
            if pos == -1:
                continue
            split = val.split('\n', 1)
            values[var] = split[0]
            self.parse_players(split[1])
        return values

    def parse_players(self, data):
        self.players = []
        for player in data.split('\n'):
            if not player:
                continue
            # Encode the player string to bytes to match against the bytes-regex
            match = self.player_reo.match(player.encode('utf-8', 'ignore'))
            if not match:
                continue
            # The matched groups will be bytes, so decode them back to strings
            frags, ping, name = match.groups()
            self.players.append(Player(1, name.decode('utf-8', 'ignore'), frags.decode(), ping.decode()))

    def update(self):
        data = self.command('getstatus')[1]
        self.values = self.parse_status(data)

    def rcon_update(self):
        data = self.rcon('status')[1]
        lines = data.split('\n')

        players = lines[3:]
        self.players = []
        for ply in players:
            while ply.find('  ') != -1:
                ply = ply.replace('  ', ' ')
            while ply.find(' ') == 0:
                ply = ply[1:]
            if ply == '':
                continue
            ply = ply.split(' ')
            try:
                self.players.append(Player(int(ply[0]), ply[3], int(ply[1]), int(ply[2]), ply[5]))
            except (IndexError, ValueError):
                continue