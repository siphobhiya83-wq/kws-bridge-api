//+------------------------------------------------------------------+
//| KWS_Portfolio_Bridge_v2.mq4                                      |
//| Kingdom Wealth Solutions                                         |
//| Posts account data to KWS Bridge API every 30 seconds           |
//| No local file writes. Works across VPS / cloud / any machine.   |
//+------------------------------------------------------------------+
#property copyright "Kingdom Wealth Solutions"
#property version   "2.00"
#property strict

//── Inputs ──────────────────────────────────────────────────────────────────
input string AccountLabel  = "Thembi Dhlomo (TeacherD1)"; // Exact account name
input string ApiUrl        = "https://YOUR-APP.onrender.com/api/update"; // Render URL
input string ApiKey        = "YOUR_API_KEY_HERE";          // Must match KWS_API_KEY env var
input int    PushInterval  = 30;                           // Seconds between pushes

//── Globals ─────────────────────────────────────────────────────────────────
datetime _lastPush = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("KWS Portfolio Bridge v2 started | Account: ", AccountLabel);
   Print("API endpoint: ", ApiUrl);
   _lastPush = 0;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if (TimeCurrent() - _lastPush < PushInterval) return;
   _lastPush = TimeCurrent();
   PushData();
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
   int total = OrdersTotal();
   int count = 0;

   for (int i = 0; i < total; i++)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

      string pos = "{";
      pos += "\"ticket\":"    + IntegerToString(OrderTicket())   + ",";
      pos += "\"symbol\":\""  + OrderSymbol()                    + "\",";
      pos += "\"type\":"      + IntegerToString(OrderType())     + ",";
      pos += "\"lots\":"      + DoubleToString(OrderLots(), 2)   + ",";
      pos += "\"open_price\":"+ DoubleToString(OrderOpenPrice(), 5) + ",";
      pos += "\"sl\":"        + DoubleToString(OrderStopLoss(), 5)  + ",";
      pos += "\"tp\":"        + DoubleToString(OrderTakeProfit(), 5) + ",";
      pos += "\"profit\":"    + DoubleToString(OrderProfit(), 2) + ",";
      pos += "\"swap\":"      + DoubleToString(OrderSwap(), 2)   + ",";
      pos += "\"comment\":\"" + OrderComment()                   + "\"";
      pos += "}";

      if (count > 0) positions += ",";
      positions += pos;
      count++;
   }

   //── Build full JSON payload ─────────────────────────────────────
   string payload = "{";
   payload += "\"account_label\":\""  + AccountLabel                              + "\",";
   payload += "\"account_number\":"   + IntegerToString(AccountNumber())          + ",";
   payload += "\"balance\":"          + DoubleToString(AccountBalance(), 2)       + ",";
   payload += "\"equity\":"           + DoubleToString(AccountEquity(), 2)        + ",";
   payload += "\"margin\":"           + DoubleToString(AccountMargin(), 2)        + ",";
   payload += "\"free_margin\":"      + DoubleToString(AccountFreeMargin(), 2)    + ",";
   payload += "\"profit\":"           + DoubleToString(AccountProfit(), 2)        + ",";
   payload += "\"currency\":\""       + AccountCurrency()                         + "\",";
   payload += "\"leverage\":"         + IntegerToString(AccountLeverage())        + ",";
   payload += "\"open_positions\":"   + IntegerToString(count)                    + ",";
   payload += "\"positions\":["       + positions                                 + "],";
   payload += "\"server_time\":"      + IntegerToString((int)TimeCurrent())       + ",";
   payload += "\"platform\":\"MT4\"";
   payload += "}";

   //── POST to API ─────────────────────────────────────────────────
   string headers = "Content-Type: application/json\r\nX-KWS-Key: " + ApiKey + "\r\n";
   char   post_data[];
   char   result[];
   string result_headers;

   StringToCharArray(payload, post_data, 0, StringLen(payload));

   int res = WebRequest(
      "POST",
      ApiUrl,
      headers,
      5000,
      post_data,
      result,
      result_headers
   );

   if (res == 200)
      Print("KWS Bridge v2: Pushed ", count, " position(s) for ", AccountLabel);
   else
      Print("KWS Bridge v2: Push failed | HTTP ", res, " | Check URL and API key");
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("KWS Portfolio Bridge v2 stopped");
}
//+------------------------------------------------------------------+
