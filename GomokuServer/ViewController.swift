//
//  ViewController.swift
//  GomokuServer
//
//  Created by yyh on 17/7/20.
//  Copyright © 2017年 yyh. All rights reserved.
//

import Cocoa
import CocoaAsyncSocket

class ViewController: NSViewController
{
    var serverSocket: GCDAsyncSocket? //创建服务端
//    var clients = [GCDAsyncSocket]()
    var clientSockets = [GCDAsyncSocket: String]() //保存所有的 socket -> preUsername
    var blackDict = [String: GCDAsyncSocket]() //黑棋client preUsername -> socket
    var blackWaitQueue = [String]() //空闲黑棋队列
    var whiteDict = [String: GCDAsyncSocket]() //白棋client preUsername -> socket
    var whiteWaitQueue = [String]() //空闲白棋队列
    var rooms = [[String]]() //给黑白分配对战房间，包括游客（观战）preUsername
    
    /* client 
    -> server(socket) -> preUsername -> rooms([preUsername]) -> [preUsername] -> [socket](by Dict)
    -> [client]
    */
    
    //显示消息
    @IBOutlet var log: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        self.log.layoutManager?.allowsNonContiguousLayout = false
        
        //开始监听
        serverSocket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        
        do {
            try serverSocket?.acceptOnPort(UInt16(1234))
            addText("Success")
        } catch _ {
            addText("Failed")
        }

        // Do any additional setup after loading the view.
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func addText(t: String) {
        let logText = t + "\n"
        log.textStorage?.appendAttributedString(NSAttributedString(string: logText))
        
        //实现调试自动滚动
        let allStrCount = (log.textStorage?.characters.count)!
        log.scrollRangeToVisible(NSMakeRange(allStrCount, 1))
    }
    
    //condition为username调用
    //用户名格式: 前缀颜色(b/w) + username
    func preUsernameWithSocket(preUsername: String, sock: GCDAsyncSocket) {
        clientSockets[sock] = preUsername
        let username = preUsername.substringFromIndex(preUsername.startIndex.advancedBy(1))
        if preUsername.hasPrefix("b") {
            blackDict[preUsername] = sock
            blackWaitQueue.append(preUsername)
            addText("black:\(username) is waiting")
        } else {
            whiteDict[preUsername] = sock
            whiteWaitQueue.append(preUsername)
            addText("white:\(username) is waiting")
        }
        matching()
    }
    
    //condition为draw..., ...Win调用
    //广播房间里的所有的client
    func broadcastToClients(data: NSData, sender: GCDAsyncSocket) {
        let room = lookUpRoomsBySenderClient(sender)
        for clients in room {
            addText("send msg to \(clients)")
            lookUpClientByPreUsernameToSendMsg(clients, data: data)
        }
        
//        if let senderPreUsername = clientSockets[sender] {
//            let room = rooms.filter { room in room.contains(senderPreUsername) }
//            for clients in room {
//                addText("send msg to \(clients)")
//                lookUpClientByPreUsernameToSendMsg(clients, data: data)
////                for client in clients {
////                    if client.hasPrefix("b") {
////                        blackDict[client]?.writeData(data, withTimeout: -1, tag: 0)
////                    } else {
////                        whiteDict[client]?.writeData(data, withTimeout: -1, tag: 0)
////                    }
////                }
//            }
//        }
    }
    
    //根据senderClient查找room
    func lookUpRoomsBySenderClient(sender: GCDAsyncSocket) -> [[String]] {
        if let senderPreUsername = clientSockets[sender] {
            let room = rooms.filter { room in room.contains(senderPreUsername) }
            return room
        }
        return [[""]]
    }
    
    //根据preUsername查找client
    func lookUpClientByPreUsernameToSendMsg(clients: [String], data: NSData) {
        for client in clients {
            if client.hasPrefix("b") {
                blackDict[client]?.writeData(data, withTimeout: -1, tag: 0)
            } else if client.hasPrefix("w") {
                whiteDict[client]?.writeData(data, withTimeout: -1, tag: 0)
            }
        }
    }
    private func lookUpClientByPreUsernameToSendMsg(client: String, data: NSData) {
        if client.hasPrefix("b") {
            blackDict[client]?.writeData(data, withTimeout: -1, tag: 0)
        } else if client.hasPrefix("w") {
            whiteDict[client]?.writeData(data, withTimeout: -1, tag: 0)
        }
    }
    private func lookUpClientByPreUsernameToSendMsg(client: String, msg: String) {
        if let data = msg.dataUsingEncoding(NSUTF8StringEncoding) {
            if client.hasPrefix("b") {
                blackDict[client]?.writeData(data, withTimeout: -1, tag: 0)
            } else if client.hasPrefix("w") {
                whiteDict[client]?.writeData(data, withTimeout: -1, tag: 0)
            }
        }
    }
    private func lookUpClientByPreUsernameToSendMsg(client: [String], msg: String) {
        if let data = msg.dataUsingEncoding(NSUTF8StringEncoding) {
            for c in client {
                if c.hasPrefix("b") {
                    blackDict[c]?.writeData(data, withTimeout: -1, tag: 0)
                } else if c.hasPrefix("w") {
                    whiteDict[c]?.writeData(data, withTimeout: -1, tag: 0)
                }
            }
        }
    }
    
    //匹配: 分配黑白到一个room中(游客)
    func matching() {
        while !blackWaitQueue.isEmpty && !whiteWaitQueue.isEmpty {
            var room = [String]()
            let black = blackWaitQueue.removeFirst()
            room.append(black)
            room.append(whiteWaitQueue.removeFirst())
            rooms.append(room)
            addText("game: \(room) start")
            lookUpClientByPreUsernameToSendMsg(black, msg: "blackEnable")
        }
    }
}

extension ViewController: GCDAsyncSocketDelegate {
    //接收到新的socket连接时执行
    func socket(sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        addText("Connect succeed")
        if let h = newSocket.connectedHost {
            addText("Host: " + String(h))
            addText("Port: " + String(newSocket.connectedPort))
        }
//        clients.append(newSocket)
        clientSockets[newSocket] = ""
        //第一次读取data
        newSocket.readDataWithTimeout(-1, tag: 0)
    }
    
    //再次读取data
    func socket(sock: GCDAsyncSocket, didReadData data: NSData, withTag tag: Int) {
        if let msg = String.init(data: data, encoding: NSUTF8StringEncoding) {
            addText(msg)
            
            //获取所有的信息
            var info = msg.componentsSeparatedByString(",")
            let condition = info.removeFirst()
            
            //根据condition进行功能选择
            switch condition {
            //连接至server时将用户名与socket、颜色绑定
            case "username":
                let preUsername = info.removeFirst()
                preUsernameWithSocket(preUsername, sock: sock)
              
            case "drawBlack", "drawWhite", "blackWin", "whiteWin": //广播给客户端处理
                broadcastToClients(data, sender: sock)
                
            default:
                break
            }
            
            //循环读取
            sock.readDataWithTimeout(-1, tag: 0)
        }
    }
}

