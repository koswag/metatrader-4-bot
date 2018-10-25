//+------------------------------------------------------------------+
//|                                                   ZMQ Server.mq4 |
//|                                           Copyright 2018, Koswag |
//|                                        https://github.com/koswag |
//+------------------------------------------------------------------+
#property copyright   "2018, Koswag"
#property link        "https://github.com/koswag"
#property description "ZMQ server expert advisor"

#include <Zmq/Zmq.mqh>

extern string  PROJECT_NAME      = "MetaTrader 4 ZMQ Server";
extern string  ZEROMQ_PROTOCOL   = "tcp";
extern string  HOSTNAME          = "*";
extern int     REP_PORT          = 5555;
extern int     PUSH_PORT         = 5556;
extern int     MILLISECOND_TIMER = 1;  // 1 millisecond

extern string  t0                = "--- Trading Parameters ---";
extern int     MagicNumber       = 123456;
extern int     MaximumOrders     = 1;
extern double  MaximumLotSize    = 0.01;
extern bool    Blocking          = false;

Context  context     (PROJECT_NAME);
Socket   repSocket   (context,ZMQ_REP);
Socket   pushSocket  (context,ZMQ_PUSH);

int     signal;
uchar   data[];
ZmqMsg  request;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
    {
      EventSetMillisecondTimer(MILLISECOND_TIMER);
      
      Print(StringFormat("[REP] Binding MT4 Server to Socket on Port %d..", REP_PORT));   
      Print(StringFormat("[PUSH] Binding MT4 Server to Socket on Port %d..", PUSH_PORT));
      
      repSocket.bind(   StringFormat(  "%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, REP_PORT  ));
      pushSocket.bind(  StringFormat(  "%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, PUSH_PORT ));
      
      //How long the thread will try to send messages after its socket has been closed
      repSocket.setLinger(1000);  // 1000 milliseconds

      //How many messages do we want to buffer in ram before closing the socket
      repSocket.setSendHighWaterMark(5);     // 5 messages only.
      
      return(INIT_SUCCEEDED);
    }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  Print("[REP] Unbinding MT4 Server from Socket on Port " + REP_PORT + "..");
  repSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, REP_PORT));
   
  Print("[PUSH] Unbinding MT4 Server from Socket on Port " + PUSH_PORT + "..");
  pushSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, PUSH_PORT));
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{  
   // Get client's response, but don't wait.
   repSocket.recv(request,true);
   
   // Pass request message to the MessageHandler
   ZmqMsg reply = MessageHandler(request);
   
   // Send reply to client
   repSocket.send(reply);
}

ZmqMsg MessageHandler(ZmqMsg &request) {
   
   // Output object
   ZmqMsg reply;
   
   // Message components for later.
   string components[];
   
   if(request.size() > 0) {
   
      // Resize Data Array to request's size 
      ArrayResize(data, request.size());
      // Store data from request in Data Array
      request.getData(data);
      // Convert Data Array to Data String
      string dataStr = CharArrayToString(data);
      
      // Parse data from Data String to Components Array
      ParseZmqMessage(dataStr, components);
      
      // Pass components to Message Interpreter
      InterpretZmqMessage(&pushSocket, components);
      
      // Construct response
      ZmqMsg ret(StringFormat("[SERVER] Processing: %s", dataStr));
      reply = ret;
   }
   else {
      // NO DATA RECEIVED
   }
   
   return(reply);
}

// Interpret Zmq Message and perform actions
void InterpretZmqMessage(Socket &pSocket, string& compArray[]) {

   Print("ZMQ: Interpreting Message..");
   
   int switch_action = 0;
   
   if(compArray[0] == "TRADE" && compArray[1] == "OPEN")
      switch_action = 1;
   if(compArray[0] == "RATES")
      switch_action = 2;
   if(compArray[0] == "TRADE" && compArray[1] == "CLOSE")
      switch_action = 3;
   if(compArray[0] == "DATA")
      switch_action = 4;
   
   string   ret      = "";
   int      ticket   = -1;
   bool     ans      = FALSE;
   
   double price_array[];
   ArraySetAsSeries(price_array, true);
   
   int price_count = 0;
   
   switch(switch_action) 
   {
      case 1: 
         InformPullClient(pSocket, "OPEN TRADE Instruction Received");
         // TODO OPEN TRADE LOGIC
         break;
      case 2: 
         ret = "N/A"; 
         if(ArraySize(compArray) > 1) 
            ret = GetBidAsk(compArray[1]); 
            
         InformPullClient(pSocket, ret); 
         break;
      case 3:
         InformPullClient(pSocket, "CLOSE TRADE Instruction Received");
         
         // IMPLEMENT CLOSE TRADE LOGIC HERE
         
         ret = StringFormat("Trade Closed (Ticket: %d)", ticket);
         InformPullClient(pSocket, ret);
         
         break;
      
      case 4:
         InformPullClient(pSocket, "HISTORICAL DATA Instruction Received");
         
         // Format: DATA|SYMBOL|TIMEFRAME|START_DATETIME|END_DATETIME
         price_count = CopyClose(compArray[1], StrToInteger(compArray[2]), 
                        StrToTime(compArray[3]), StrToTime(compArray[4]), 
                        price_array);
         
         if (price_count > 0) {
            
            ret = "";
            
            // Construct string of price|price|price|.. etc and send to PULL client.
            for(int i = 0; i < price_count; i++ ) {
               
               if(i == 0)
                  ret = compArray[1] + "|" + DoubleToStr(price_array[i], 5);
               else if(i > 0) {
                  ret = ret + "|" + DoubleToStr(price_array[i], 5);
               }   
            }
            
            Print("Sending: " + ret);
            
            // Send data to PULL client.
            InformPullClient(pSocket, StringFormat("%s", ret));
            // ret = "";
         }
            
         break;
         
      default: 
         break;
   }
}

// Parse Zmq Message
void ParseZmqMessage(string& message, string& retArray[]) {
   
   Print("Parsing: " + message);
   
   string sep = "|";
   ushort u_sep = StringGetCharacter(sep,0);
   
   int splits = StringSplit(message, u_sep, retArray);
   
   for(int i = 0; i < splits; i++) {
      Print(i + ") " + retArray[i]);
   }
}

//+------------------------------------------------------------------+
// Generate string for Bid/Ask by symbol
string GetBidAsk(string symbol) {
   
   double bid = MarketInfo(symbol, MODE_BID);
   double ask = MarketInfo(symbol, MODE_ASK);
   
   return(StringFormat("%f|%f", bid, ask));
}

// Inform Client
void InformPullClient(Socket& pushSocket, string message) {

   ZmqMsg pushReply(StringFormat("[SERVER]: %s", message));
   
   pushSocket.send(pushReply, Blocking);
   
}