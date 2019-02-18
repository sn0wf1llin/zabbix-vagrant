#! /root/miniconda3/envs/py27/bin/python

import json
import urllib2
from urllib2 import URLError
import sys, argparse
import xlrd
import socket
import os

creds = {
	"user": "Admin",
	"password": "zabbix",
}

url = 'http://' + "192.168.33.10" + '/api_jsonrpc.php'
header = {"Content-Type": "application/json"}

CLR_FIN = "\033[0m"
CLR_OK = "\033[42m"
CLR_WARN = "\033[43m"
CLR_INFO = "\033[44m"
CLR_FAIL = "\033[41m"

def user_login():
    data = json.dumps({
        "jsonrpc": "2.0",
        "method": "user.login",
        "params": creds,
        "id": 0
    })

    request = urllib2.Request(url, data)
    for key in header:
        request.add_header(key, header[key])

    try:
        result = urllib2.urlopen(request)

    except URLError as e:
        print "{} error ! {} code : {}".format(CLR_FAIL, CLR_FIN, e.code)
    else:
        response = json.loads(result.read())
        result.close()

        # print response
        authID = response['result']
        
        return authID


def hostgroup_get(hostgroup_name=''):
    data = json.dumps({
        "jsonrpc": "2.0",
        "method": "hostgroup.get",
        "params": {
            "output": "extend",
            "filter": {
                "name": hostgroup_name
            }
        },
        "auth": user_login(),
        "id": 1,
    })

    request = urllib2.Request(url, data)
    for key in header:
        request.add_header(key, header[key])

    try:
        result = urllib2.urlopen(request)
    except URLError as e:
        print "Error as ", e
    else:
        # print result.read()
        response = json.loads(result.read())
        result.close()
        # print response()
        for group in response['result']:
            if len(hostgroup_name) == 0:
                print "hostgroup:  {}{}{} \tgroupid : {}".format(CLR_FAIL, group['name'], CLR_FIN, group['groupid'])
            else:
                print "hostgroup:  {}{}{}\tgroupid : {}".format(CLR_FAIL, group['name'], CLR_FIN, group['groupid'])
                hostgroupID = group['groupid']
                return group['groupid']


def hostgroup_create(hostgroup_name):
    if hostgroup_get(hostgroup_name):
        print "hostgroup  {}{}{} is exist !".format(CLR_FAIL, hostgroup_name, CLR_FIN)
        sys.exit(1)
    
    data = json.dumps({
        "jsonrpc": "2.0",
        "method": "hostgroup.create",
        "params": {
            "name": hostgroup_name
        },
        "auth": user_login(),
        "id": 1
    })
    request = urllib2.Request(url, data)

    for key in header:
        request.add_header(key, header[key])

    try:
        result = urllib2.urlopen(request)
    except URLError as e:
        print "Error as ", e
    else:
        response = json.loads(result.read())
        result.close()
        print "{} result:{}{}  hostgroupID : {}".format(CLR_WARN, hostgroup_name, CLR_FIN, response['result']['groupids'])

def template_get(template_name=''):
    data = json.dumps({
        "jsonrpc": "2.0",
        "method": "template.get",
        "params": {
            "output": "extend",
            "filter": {
                "name": template_name
            }
        },
        "auth": user_login(),
        "id": 1,
    })

    request = urllib2.Request(url, data)
    for key in header:
        request.add_header(key, header[key])

    try:
        result = urllib2.urlopen(request)
    except URLError as e:
        print "Error as ", e
    else:
        response = json.loads(result.read())
        result.close()
        # print response
        for template in response['result']:
            if len(template_name) == 0:
                print "template : {}{}{}\t  id : {}".format(CLR_FAIL, template['name'], CLR_FIN, template['templateid'])
            else:
                templateID = response['result'][0]['templateid']
                print "Template Name :  {}{}{} ".format(CLR_FAIL, template_name, CLR_FIN)
                return response['result'][0]['templateid']


def host_get(host_name=''):
    data = json.dumps({
        "jsonrpc": "2.0",
        "method": "host.get",
        "params": {
            "output": "extend",
            "filter": {"host": host_name}
        },
        "auth": user_login(),
        "id": 1
    })

    request = urllib2.Request(url, data)
    for key in header:
        request.add_header(key, header[key])

    try:
        result = urllib2.urlopen(request)
    except URLError as e:
        if hasattr(e, 'reason'):
            print 'We failed to reach a server.'
            print 'Reason: ', e.reason
        elif hasattr(e, 'code'):
            print 'The server could not fulfill the request.'
            print 'Error code: ', e.code
    else:
        response = json.loads(result.read())
        # print response
        result.close()
        print "result: {}{}{}".format(CLR_FAIL, len(response['result']), CLR_FIN)
        for host in response['result']:
            status = {"0": "OK", "1": "Disabled"}
            available = {"0": "Unknown", "1": "available", "2": "Unavailable"}
            # print host
            
            if len(host_name) == 0:
                print "HostID : {}\t HostName : {}\t Status :{}{}{} \t Available : {}{}{}".format(
                host['hostid'], host['name'], CLR_WARN, status[host['status']], CLR_FIN, CLR_WARN, available[host['available']], CLR_FIN)
            
            else:
                print "HostID : {}\t HostName : {}\t Status :{}{}{} \t Available : {}{}{}".format(
                host['hostid'], host['name'], CLR_INFO, status[host['status']], CLR_FIN, CLR_INFO, available[host['available']], CLR_FIN)
                
                return host['hostid']

def host_create(hostdata):
    if host_get(hostdata["IP"]):
        print "{} host ip {} exists!{}".format(CLR_OK, hostdata["IP"], CLR_FIN)
        sys.exit(1)

    group_list = []
    template_list = []
    for i in hostdata["groups"].split(','):
        var = {}
        var['groupid'] = hostgroup_get(i)
        group_list.append(var)
    
    for i in hostdata["templates"].split(','):
        var = {}
        var['templateid'] = template_get(i)
        template_list.append(var)

    data = json.dumps({
        "jsonrpc": "2.0",
        "method": "host.create",
        "params": {
            "host": hostdata["hostname"],
            "interfaces": [
                {
                    "type": 1,
                    "main": 1,
                    "useip": 1,
                    "ip": hostdata["IP"],
                    "dns": "",
                    "port": hostdata["port"]
                }
            ],
            "templates": template_list,
            "groups": group_list,
        },
        "auth": user_login(),
        "id": 1
    })

    request = urllib2.Request(url, data)
    for key in header:
        request.add_header(key, header[key])

    try:
        result = urllib2.urlopen(request)

        response = json.loads(result.read())
        result.close()
        print "result: {}{}{} \tid : {}{}{}".format(CLR_OK, hostdata["IP"], CLR_FIN, CLR_INFO, response['result']['hostids'], CLR_FIN)

    except URLError as e:
        print "{}Error as {}".format(CLR_FAIL, e, CLR_FIN)

    except Exception, e:
    	print e
    	print "{}Details {} : {} {}".format(CLR_INFO, CLR_FIN, response["error"]["message"], response["error"]["data"])


if __name__ == "__main__":
	hostgroup_name = "TestGroup2"
	hostgroup_create(hostgroup_name)

	group_id = hostgroup_get(hostgroup_name)
	print(group_id)

	host_data = {
		"IP": "192.168.33.66",
		"groups": hostgroup_name,
		"port": 10050,
		"hostname": "TestHost2",
		"templates": "Template OS Linux",

	}
	host_create(host_data)