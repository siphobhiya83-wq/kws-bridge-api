//+------------------------------------------------------------------+
//| KWS_Portfolio_Bridge_v2.mq5                                      |
//| Kingdom Wealth Solutions                                         |
//| Posts account data to KWS Bridge API every 30 seconds           |
//| No local file writes. Works across VPS / cloud / any machine.   |
//+------------------------------------------------------------------+
#property copyright "Kingdom Wealth Solutions"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

//── Inputs ──────────────────────────────────────────────────────────────────
input string AccountLabel  = "Mrs Mqadi";                          // Exact account name
input string ApiUrl        = "https://YOUR-APP.onrender.com/api/update"; // Render URL
input string ApiKey        = "YOUR_API_KEY_HERE";                  // Must match KWS_API_KEY
input int    PushInterval  = 30;                                   // Seconds between pushes

//── Globals ─────────────────────────────────────────────────────────────────
datetime _lastPush = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("KWS Portfolio Bridge v2 (MT5) started | Account: ", AccountLabel);
   Print("API endpoint: ", ApiUrl);
   EventSetTimer(PushInterval);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("KWS Portfolio Bridge v2 (MT5) stopped");
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Timer handles the pushing — OnTick just keeps EA alive
}

//+------------------------------------------------------------------+
void OnTimer()
{
   PushData();
}

//+------------------------------------------------------------------+
void PushData()
{
   //── Build positions array ───────────────────────────────────────
   string positions = "";
   int total = PositionsTotal();
   int count = 0;

   for (int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;

      string pos = "{";
      pos += "\"ticket\":"     + IntegerToString(ticket)                                    + ",";
      pos += "\"symbol\":\""   + PositionGetString(POSITION_SYMBOL)                         + "\",";
      pos += "\"type\":"       + IntegerToString((int)PositionGetInteger(POSITION_TYPE))    + ",";
      pos += "\"lots\":"       + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2)      + ",";
      pos += "\"open_price\":" + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), 5) + ",";
      pos += "\"sl\":"         + DoubleToString(PositionGetDouble(POSITION_SL), 5)         + ",";
      pos += "\"tp\":"         + DoubleToString(PositionGetDouble(POSITION_TP), 5)         + ",";
      pos += "\"profit\":"     + DoubleToString(PositionGetDouble(POSITION_PROFIT), 2)     + ",";
      pos += "\"swap\":"       + DoubleToString(PositionGetDouble(POSITION_SWAP), 2)       + ",";
      pos += "\"comment\":\""  + PositionGetString(POSITION_COMMENT)                        + "\"";
      pos += "}";

      if (count > 0) positions += ",";
      positions += pos;
      count++;
   }

   //── Account info ────────────────────────────────────────────────
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin     = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double profit     = AccountInfoDouble(ACCOUNT_PROFIT);
   string currency   = AccountInfoString(ACCOUNT_CURRENCY);
   long   leverage   = AccountInfoInteger(ACCOUNT_LEVERAGE);
   long   accNumber  = AccountInfoInteger(ACCOUNT_LOGIN);

   //── Build full JSON payload ─────────────────────────────────────
   string payload = "{";
   payload += "\"account_label\":\""  + AccountLabel                        + "\",";
   payload += "\"account_number\":"   + IntegerToString(accNumber)          + ",";
   payload += "\"balance\":"          + DoubleToString(balance, 2)          + ",";
   payload += "\"equity\":"           + DoubleToString(equity, 2)           + ",";
   payload += "\"margin\":"           + DoubleToString(margin, 2)           + ",";
   payload += "\"free_margin\":"      + DoubleToString(freeMargin, 2)       + ",";
   payload += "\"profit\":"           + DoubleToString(profit, 2)           + ",";
   payload += "\"currency\":\""       + currency                            + "\",";
   payload += "\"leverage\":"         + IntegerToString(leverage)           + ",";
   payload += "\"open_positions\":"   + IntegerToString(count)              + ",";
   payload += "\"positions\":["       + positions                           + "],";
   payload += "\"server_time\":"      + IntegerToString((int)TimeTradeServer()) + ",";
   payload += "\"platform\":\"MT5\"";
   payload += "}";

   //── POST to API ─────────────────────────────────────────────────
   string headers = "Content-Type: application/json\r\nX-KWS-Key: " + ApiKey + "\r\n";
   char   post_data[];
   char   result[];
   string result_headers;
   int    timeout = 5000;

   StringToCharArray(payload, post_data, 0, StringLen(payload));

   int res = WebRequest(
      "POST",
      ApiUrl,
      headers,
      timeout,
      post_data,
      result,
      result_headers
   );

   if (res == 200)
      Print("KWS Bridge v2 (MT5): Pushed ", count, " position(s) for ", AccountLabel);
   else
      Print("KWS Bridge v2 (MT5): Push failed | HTTP ", res,
            " | Check URL, API key, and WebRequest permissions");
}
//+------------------------------------------------------------------+
