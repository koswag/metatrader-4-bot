//+------------------------------------------------------------------+
//|                                                   ZMQ Server.mq4 |
//|                                           Copyright 2018, Koswag |
//|                                        https://github.com/koswag |
//+------------------------------------------------------------------+
#property copyright   "2018, Koswag"
#property link        "https://github.com/koswag"
#property description "ZMQ server expert advisor"
#property version     "1.00"

#include <Zmq/Zmq.mqh>

extern string  PROJECT_NAME = "MetaTrader 4 ZMQ Server";
extern string  ZEROMQ_PROTOCOL = "tcp";
extern string  HOSTNAME  = "*";
extern int     IN_PORT = 1111;
extern int     OUT_PORT = 2222;
extern int     MILLISECOND_TIMER = 1;

extern string  t0                = "--- Trading Parameters ---";
extern int     MagicNumber       = 123456;
extern int     MaximumOrders     = 1;
extern double  MaximumLotSize    = 0.01;
extern bool    Blocking          = false;
extern int     Slippage          = 3;

Context  context     (PROJECT_NAME);
Socket   PullSocket  (context, ZMQ_PULL);
Socket   PushSocket  (context, ZMQ_PUSH);

int      Ticket;
double   StopLossLevel, TakeProfitLevel;

ZmqMsg   request;
string   operation;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    EventSetMillisecondTimer(MILLISECOND_TIMER);
      
    Print(StringFormat("[REP] Binding MT4 Server to Socket on Port %d..", IN_PORT));   
    PullSocket.bind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, IN_PORT));

    Print(StringFormat("[PUSH] Binding MT4 Server to Socket on Port %d..", OUT_PORT));
    PushSocket.bind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, OUT_PORT));
      
    //How long the thread will try to send messages after its socket has been closed
    PullSocket.setLinger(1000);  // 1000 milliseconds

    //How many messages do we want to buffer before closing the socket:
    PullSocket.setSendHighWaterMark(5);     // Up to 5 messages.
      
    return(INIT_SUCCEEDED);
}
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  Print(StringFormat("[REP] Unbinding MT4 Server from Socket on Port %d..", IN_PORT));
  PullSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, IN_PORT));

  Print(StringFormat("[PUSH] Unbinding MT4 Server from Socket on Port %d..", OUT_PORT));
  PushSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, OUT_PORT));
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
  PullSocket.recv(request, true);
  
  if(request.size() > 0)
    MessageHandler(request);
}

//+------------------------------------------------------------------+

void MessageHandler(ZmqMsg &req) 
{
  string msg, components[];
  
  msg = GetMessage(req);

  Print(StringFormat("Message received : %s", msg));

  ParseZmqMessage(msg, components);
  InterpretZmqMessage(&PushSocket, components);
}

string GetMessage(ZmqMsg& message)
{
  uchar bytes[];

  ArrayResize(bytes, message.size());
  message.getData(bytes);
  return CharArrayToString(bytes);
}

// Interpret Zmq Message and perform actions
void InterpretZmqMessage(Socket& pSocket, string& compArray[])
{
  Print("ZMQ: Interpreting Message..");
   
  int action = GetAction(compArray[0], compArray[1]);
   
  string response = "";

  double barData[4], value = NULL;
  bool orderClosed = false;
  int OP, clr = clrNONE;


  switch(action)
  {
    case 1: 
      Send("OPEN TRADE Instruction Received");

      OP = StrToInteger(compArray[2]);
         
      if(OP == 0)
      {
        operation = "BUY";
        StopLossLevel = Ask - StrToDouble(compArray[5]) * Point;
        TakeProfitLevel = Ask + StrToDouble(compArray[6]) * Point;
        value = Ask;
        clr = clrGreen;
      }
      else if(OP == 1)
      {
        operation = "SELL";
        StopLossLevel = Bid + StrToDouble(compArray[5]) * Point;
        TakeProfitLevel = Bid - StrToDouble(compArray[6]) * Point;
        value = Bid;
        clr = clrDarkCyan;
      }
         
      Ticket = OrderSend(compArray[3], OP, MaximumLotSize, value, Slippage, StopLossLevel, 
                          TakeProfitLevel, StringFormat("%s order: %d", operation, MagicNumber), 
                            MagicNumber, 0, clrGreen);

      if(Ticket > 0)
      {
        if(OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES))
          response = StringFormat("SELL order opened : %d", OrderOpenPrice());
        else
          response = StringFormat("OrderSend failed: %s", GetLastError());
      } 
      else
        response = StringFormat("Ticket not sent: %s", GetLastError());
         
      break;

    case 2: 
      response = "N/A";

      if(ArraySize(compArray) > 1) 
        response = GetBidAsk(compArray[1]); 

      break;

    case 3:
      Send("CLOSE TRADE Instruction Received");
         
      OP = StrToInteger(compArray[2]);
      Ticket = StrToInteger(compArray[8]);
         
      if(OP == 0)
      {
        value = Bid;
        clr = clrRed;
      } 
      else if(OP == 1)
      {
        value = Ask;
        clr = clrOrange;
      }

      if(OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES))
        orderClosed = OrderClose(OrderTicket(), OrderLots(), value, Slippage, clr);  

      if(orderClosed)
        response = StringFormat("Trade Closed (Ticket: %d)", Ticket);
      else
        response = StringFormat("Error : %s", GetLastError());

      break;

    case 4:
      Send("DATA Instruction Received");
         
      FillBarData(barData, compArray[1]);
         
      response = StringFormat("%.4f|%.4f|%.4f|%.4f", barData[0], barData[1], barData[2], barData[3]);
         
      break;
  }
  
  Print("Sending: " + response);
  Send(response);
}

// Message parser
void ParseZmqMessage(string message, string &retArray[])
{
  Print("Parsing: " + message);
   
  string sep = "|";
  ushort u_sep = StringGetCharacter(sep,0);
   
  int splits = StringSplit(message, u_sep, retArray);
   
  for(int i = 0; i < splits; i++)
    Print(StringFormat("%d) %s", i, retArray[i]));
}

//+------------------------------------------------------------------+

// Generate string for Bid/Ask by symbol
string GetBidAsk(string symbol) 
{   
  double bid = MarketInfo(symbol, MODE_BID);
  double ask = MarketInfo(symbol, MODE_ASK);
   
  return(StringFormat("%f|%f", bid, ask));
}

//Returns action number for request and operation
int GetAction(string req, string op = NULL){

  if(req == "TRADE" && op == "OPEN")
    return 1;
  if(req == "RATES")
    return 2;
  if(req == "TRADE" && op == "CLOSE")
    return 3;
  if(req == "DATA")
    return 4;
  return 0;
}

//Gets latest bar data
void FillBarData(double &barData[], string symbol)
{
  barData[0] = iOpen(symbol, PERIOD_H1, 0);
  barData[1] = iClose(symbol, PERIOD_H1, 0);
  barData[2] = iHigh(symbol, PERIOD_H1, 0);
  barData[3] = iLow(symbol, PERIOD_H1, 0);
}

//Sends string message to client
void Send(string message) 
{
  if(message != "" || message != NULL){
    ZmqMsg pushReply(StringFormat("[SERVER] : %s", message));
   
    Print(StringFormat("Sending message : %s", message));
    PushSocket.send(pushReply, Blocking);
  }
}
