#property copyright "Copyright 2025 @ yt"
#property link      "https://script.google.com"
#property version   "2.00"
#property strict

// アイコンをEAバイナリに埋め込む
#resource "\\Include\\GridEA\\euroblade_icon.bmp"

#include <Trade\Trade.mqh>
#include <GridEA\GridDashboard.mqh>

//--- 時間ソースを選択するためのenum
enum ENUM_TIME_SOURCE
{
    BROKER_TIME, // ブローカー時間
    PC_TIME      // PCのローカル時間
};

//+------------------------------------------------------------------+
//| EAの入力パラメータ                                                |
//+------------------------------------------------------------------+
input bool   UseAuthentication      = false;  // 口座認証を使用するか (falseで無効化)
input double InitialLots            = 0.01;   // 初期ロット数
input int    GridWidthPips          = 5;      // ナンピンする価格差 (pips)
input int    WaitMinutesAfterNanpin = 10;     // 前回のナンピンからの待機時間 (分)
input int    TakeProfitPips         = 5;      // 利益確定pips (平均建値からのpips)
input string TradeComment           = "EuroBlade"; // 取引コメント
input int    MagicNumber            = 2025;   // マジックナンバー
input ENUM_TIME_SOURCE TimeSource   = PC_TIME;     // 使用する時間基準 (ブローカー/PC)
input int    StartHour              = 0;      // EA稼働を開始する時刻 (時)
input int    EndHour                = 24;     // EA稼働を終了する時刻 (時)
input bool   ClosePositionsAtEndTime = false; // 時間外に強制的に決済を入れるか

//--- トレーリング設定
input int    TrailingStartCount   = 3;       // 何段目からトレーリングを開始するか
input bool   UseBreakEvenTrail    = true;    // 損益分岐到達後にトレーリング
input bool   UseDirectTrail       = false;   // 即トレーリング（平均建値+X pipsで開始）
input int    TrailingTriggerPips   = 3;      // トレーリング開始トリガー (平均建値から+Xpips)
input int    TrailingStepPips      = 2;      // トレーリングのステップ幅 (pips)

//--- MAトレンドフィルター設定
input bool            UseMAFilter  = false;          // MAトレンドフィルターを使用するか
input int             MA_Period    = 21;             // MA期間
input ENUM_MA_METHOD  MA_Method    = MODE_EMA;       // MA種別
input ENUM_TIMEFRAMES MA_UpperTF   = PERIOD_H1;      // 上位足タイムフレーム
input ENUM_TIMEFRAMES MA_LowerTF   = PERIOD_M5;      // 下位足タイムフレーム
input bool            UseUpperTF   = true;           // 上位足MAチェックを使用するか
input bool            UseLowerTF   = false;          // 下位足MAチェックを使用するか

//--- グローバル変数
CTrade         trade;
CGridDashboard dashboard;
string         expert_name     = "EuroBlade";
double         pips_to_points;
bool           WasInTradingTime = false;

bool           g_entryEnabled   = true;
bool           g_isJPY          = false;
datetime       g_lastDashUpdate = 0;

double         g_trailStopBuy  = 0;
double         g_trailStopSell = 0;

// チャート元色保存用
ENUM_CHART_PROPERTY_INTEGER g_colorProps[13];
color                       g_savedColors[13];

//+------------------------------------------------------------------+
//| 現在がEAの稼働時間内か判定する                                    |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
    if(StartHour == EndHour) return true;

    datetime baseTime = (TimeSource == BROKER_TIME) ? TimeCurrent() : TimeLocal();
    MqlDateTime currentTime;
    TimeToStruct(baseTime, currentTime);
    int currentHour = currentTime.hour;

    if(StartHour < EndHour)
        return (currentHour >= StartHour && currentHour < EndHour);
    else
        return (currentHour >= StartHour || currentHour < EndHour);
}

//+------------------------------------------------------------------+
//| MAトレンド判定 (1=上昇, -1=下降, 0=判定不能)                     |
//+------------------------------------------------------------------+
int GetMATrend(ENUM_TIMEFRAMES tf)
{
    int handle = iMA(_Symbol, tf, MA_Period, 0, MA_Method, PRICE_CLOSE);
    if(handle == INVALID_HANDLE) return 0;
    double ma[];
    ArraySetAsSeries(ma, true);
    int copied = CopyBuffer(handle, 0, 0, 2, ma);
    IndicatorRelease(handle);
    if(copied < 2) return 0;
    return (ma[0] > ma[1]) ? 1 : -1;
}

//+------------------------------------------------------------------+
//| MA方向に基づくエントリー許可判定                                  |
//+------------------------------------------------------------------+
bool IsEntryAllowedByMA(ENUM_POSITION_TYPE type)
{
    if(!UseMAFilter) return true;

    int curTrend = GetMATrend(PERIOD_CURRENT);

    if(UseUpperTF)
    {
        int upTrend = GetMATrend(MA_UpperTF);
        if(type == POSITION_TYPE_BUY  && upTrend < 0) return false;
        if(type == POSITION_TYPE_SELL && upTrend > 0) return false;
    }

    if(UseLowerTF)
    {
        int lowTrend = GetMATrend(MA_LowerTF);
        if(type == POSITION_TYPE_BUY  && lowTrend < 0) return false;
        if(type == POSITION_TYPE_SELL && lowTrend > 0) return false;
    }

    if(type == POSITION_TYPE_BUY  && curTrend < 0) return false;
    if(type == POSITION_TYPE_SELL && curTrend > 0) return false;

    return true;
}

//+------------------------------------------------------------------+
//| 口座認証                                                          |
//+------------------------------------------------------------------+
bool CheckAuthentication()
{
    if(MQLInfoInteger(MQL_TESTER))
    {
        Print("バックテストモードのため、口座認証をスキップします。");
        return true;
    }

    long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
    if(accountNumber <= 0) { Print("口座番号の取得に失敗しました。"); return false; }

    string url = "https://script.google.com/macros/s/AKfycbzCDhKLSH9LHaK40XuntdSLlcqRrMpJV5DUPAhGKdOSZd8bHwWxZgDignQ82iXTyY5y/exec?account=" + (string)accountNumber;
    char result[]; string headers; int timeout = 22300;
    ResetLastError();
    char post_data[];
    int resCode = WebRequest("GET", url, NULL, NULL, timeout, post_data, 0, result, headers);

    if(resCode == -1)
    {
        Print("WebRequestでエラー: ", GetLastError());
        Alert("認証サーバーへの接続に失敗しました。");
        return false;
    }
    if(resCode != 200)
    {
        Print("HTTP ", resCode);
        Alert("認証サーバーが応答しませんでした。(HTTP ", resCode, ")");
        return false;
    }

    string response = CharArrayToString(result);
    if(response == "true")
    {
        Print("口座認証成功。口座番号: ", accountNumber);
        return true;
    }
    Print("口座認証失敗。口座番号: ", accountNumber, " Response: ", response);
    return false;
}

//+------------------------------------------------------------------+
//| チャートをライトモードに変更し、元の色を保存する                  |
//+------------------------------------------------------------------+
void ApplyLightModeChart()
{
    g_colorProps[0]  = CHART_COLOR_BACKGROUND;
    g_colorProps[1]  = CHART_COLOR_FOREGROUND;
    g_colorProps[2]  = CHART_COLOR_GRID;
    g_colorProps[3]  = CHART_COLOR_VOLUME;
    g_colorProps[4]  = CHART_COLOR_CHART_UP;
    g_colorProps[5]  = CHART_COLOR_CHART_DOWN;
    g_colorProps[6]  = CHART_COLOR_CHART_LINE;
    g_colorProps[7]  = CHART_COLOR_CANDLE_BULL;
    g_colorProps[8]  = CHART_COLOR_CANDLE_BEAR;
    g_colorProps[9]  = CHART_COLOR_BID;
    g_colorProps[10] = CHART_COLOR_ASK;
    g_colorProps[11] = CHART_COLOR_LAST;
    g_colorProps[12] = CHART_COLOR_STOP_LEVEL;

    color lightColors[13];
    lightColors[0]  = clrWhite;           // 背景
    lightColors[1]  = clrBlack;           // 文字・軸
    lightColors[2]  = C'210,210,220';     // グリッド
    lightColors[3]  = C'100,100,180';     // ボリューム
    lightColors[4]  = C'0,120,0';         // 上昇バー/ヒゲ
    lightColors[5]  = C'180,0,0';         // 下降バー/ヒゲ
    lightColors[6]  = C'0,80,160';        // ラインチャート
    lightColors[7]  = C'220,240,220';     // 陽線ボディ
    lightColors[8]  = C'240,220,220';     // 陰線ボディ
    lightColors[9]  = C'0,100,0';         // BIDライン
    lightColors[10] = C'180,0,0';         // ASKライン
    lightColors[11] = C'0,0,180';         // 最終取引価格ライン
    lightColors[12] = C'200,100,0';       // ストップレベル

    for(int i = 0; i < 13; i++)
    {
        g_savedColors[i] = (color)ChartGetInteger(0, g_colorProps[i]);
        ChartSetInteger(0, g_colorProps[i], lightColors[i]);
    }
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| チャートの色を元に戻す                                            |
//+------------------------------------------------------------------+
void RestoreChartColors()
{
    for(int i = 0; i < 13; i++)
        ChartSetInteger(0, g_colorProps[i], g_savedColors[i]);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| アイコンをチャート右下に表示                                      |
//+------------------------------------------------------------------+
void CreateIcon()
{
    string name = "GD_Icon";
    ObjectCreate(0, name, OBJ_BITMAP_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_RIGHT_LOWER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  10);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  10);
    ObjectSetString(0,  name, OBJPROP_BMPFILE,    "::Include\\GridEA\\euroblade_icon.bmp");
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    // 口座認証（UseAuthentication=falseで無効化）
    if(UseAuthentication && !CheckAuthentication())
    {
        Alert("口座認証に失敗したため、EAを停止します。");
        return INIT_FAILED;
    }

    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetTypeFillingBySymbol(_Symbol);

    pips_to_points = (SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 ||
                      SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5) ? 10.0 : 1.0;

    // JPY口座判定
    g_isJPY = (AccountInfoString(ACCOUNT_CURRENCY) == "JPY");

    // チャートをライトモードに
    ApplyLightModeChart();

    // アイコン表示
    CreateIcon();

    // ダッシュボード作成
    dashboard.Create(20, 30, g_isJPY);
    dashboard.SetEntryEnabled(g_entryEnabled);

    // 初回即時更新
    int tc = UseMAFilter ? GetMATrend(PERIOD_CURRENT) : 0;
    int tu = (UseMAFilter && UseUpperTF) ? GetMATrend(MA_UpperTF) : 0;
    int tl = (UseMAFilter && UseLowerTF) ? GetMATrend(MA_LowerTF) : 0;
    dashboard.Update(MagicNumber, g_trailStopBuy, g_trailStopSell,
                     tc, tu, tl, UseMAFilter);
    g_lastDashUpdate = TimeCurrent() - TimeCurrent() % 60;

    Print(expert_name, " initialized. JPY=", g_isJPY, " Auth=", UseAuthentication);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    dashboard.Destroy();
    RestoreChartColors();
    RemovePendingOrders();
    Print(expert_name, " deinited. reason=", reason);
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    // 稼働時間判定
    bool isInTime = IsTradingTime();

    // 時間外決済
    if(ClosePositionsAtEndTime && WasInTradingTime && !isInTime)
    {
        CloseAllPositions(POSITION_TYPE_BUY);
        CloseAllPositions(POSITION_TYPE_SELL);
    }
    WasInTradingTime = isInTime;

    // 売買ロジック（毎Tick）
    if(g_entryEnabled && isInTime)
        CheckAndPlaceInitialPositions();

    CheckAndPlaceNanpin();
    CheckAndCloseGrid();
    CheckAndTrailGrid();

    // ダッシュボード更新（1分ごと）
    datetime currentMinute = TimeCurrent() - TimeCurrent() % 60;
    if(currentMinute > g_lastDashUpdate)
    {
        int tCur = UseMAFilter ? GetMATrend(PERIOD_CURRENT) : 0;
        int tUp  = (UseMAFilter && UseUpperTF) ? GetMATrend(MA_UpperTF) : 0;
        int tLow = (UseMAFilter && UseLowerTF) ? GetMATrend(MA_LowerTF) : 0;
        dashboard.Update(MagicNumber, g_trailStopBuy, g_trailStopSell,
                         tCur, tUp, tLow, UseMAFilter);
        g_lastDashUpdate = currentMinute;
    }
}

//+------------------------------------------------------------------+
//| OnChartEvent — ボタンクリック検知                                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK && sparam == "GD_BtnEntry")
    {
        g_entryEnabled = !g_entryEnabled;
        dashboard.SetEntryEnabled(g_entryEnabled);
        Print(expert_name, " 新規エントリー: ", g_entryEnabled ? "ON" : "OFF");
    }
}

//+------------------------------------------------------------------+
//| OnTester — バックテスト完了時のサマリーログ                       |
//+------------------------------------------------------------------+
double OnTester()
{
    // 全取引履歴を選択
    HistorySelect(0, TimeCurrent());

    int    totalTrades = 0;
    double totalProfit = 0.0;
    double totalLots   = 0.0;
    double maxDD       = 0.0;
    double peakProfit  = 0.0;
    double runningPnl  = 0.0;

    int deals = HistoryDealsTotal();
    for(int i = 0; i < deals; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket == 0) continue;
        if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
        if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;

        ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;

        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                      + HistoryDealGetDouble(ticket, DEAL_SWAP)
                      + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        double vol    = HistoryDealGetDouble(ticket, DEAL_VOLUME);

        totalProfit += profit;
        totalLots   += vol;
        totalTrades++;

        // ドローダウン計算
        runningPnl += profit;
        if(runningPnl > peakProfit) peakProfit = runningPnl;
        double dd = peakProfit - runningPnl;
        if(dd > maxDD) maxDD = dd;
    }

    double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
    double profitRate = (balance > 0) ? totalProfit / balance * 100.0 : 0.0;

    Print("========================================");
    Print(" EuroBlade バックテスト結果サマリー");
    Print("========================================");
    Print(" 総取引回数 : ", totalTrades, " 回");
    Print(" 合計ロット : ", DoubleToString(totalLots, 2), " lot");
    Print(" 純損益     : ", DoubleToString(totalProfit, (g_isJPY ? 0 : 2)),
          (g_isJPY ? " JPY" : " USD"));
    Print(" 利率       : ", DoubleToString(profitRate, 2), " %");
    Print(" 最大DD     : ", DoubleToString(maxDD, (g_isJPY ? 0 : 2)),
          (g_isJPY ? " JPY" : " USD"));
    Print("========================================");

    return totalProfit;
}

//+------------------------------------------------------------------+
//| 初期ポジション配置                                                |
//+------------------------------------------------------------------+
void CheckAndPlaceInitialPositions()
{
    if(CountPositions(POSITION_TYPE_BUY) == 0 && IsEntryAllowedByMA(POSITION_TYPE_BUY))
    {
        RemovePendingOrders(ORDER_TYPE_BUY_LIMIT);
        trade.Buy(InitialLots, _Symbol, 0, 0, 0, TradeComment);
    }
    if(CountPositions(POSITION_TYPE_SELL) == 0 && IsEntryAllowedByMA(POSITION_TYPE_SELL))
    {
        RemovePendingOrders(ORDER_TYPE_SELL_LIMIT);
        trade.Sell(InitialLots, _Symbol, 0, 0, 0, TradeComment);
    }
}

//+------------------------------------------------------------------+
//| ナンピン判定・実行                                                |
//+------------------------------------------------------------------+
void CheckAndPlaceNanpin()
{
    if(CountPositions(POSITION_TYPE_BUY)  > 0) AddNanpinPosition(POSITION_TYPE_BUY);
    if(CountPositions(POSITION_TYPE_SELL) > 0) AddNanpinPosition(POSITION_TYPE_SELL);
}

void AddNanpinPosition(ENUM_POSITION_TYPE type)
{
    datetime last_position_time  = 0;
    double   last_position_price = 0;
    if(!GetLastPositionInfo(type, last_position_time, last_position_price)) return;

    if(TimeCurrent() - last_position_time < WaitMinutesAfterNanpin * 60) return;

    double current_price = (type == POSITION_TYPE_BUY)
                           ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double required = GridWidthPips * _Point * pips_to_points;
    double diff     = (type == POSITION_TYPE_BUY)
                      ? last_position_price - current_price
                      : current_price - last_position_price;

    if(diff < required) return;

    int count = CountPositions(type);
    if(count >= 25) return;

    double lots[25];
    CalculateFibonacciLots(lots);
    double lot_size = NormalizeLot(lots[count]);
    if(lot_size <= 0) return;

    if(type == POSITION_TYPE_BUY)
        trade.Buy(lot_size, _Symbol, 0, 0, 0, TradeComment);
    else
        trade.Sell(lot_size, _Symbol, 0, 0, 0, TradeComment);
}

//+------------------------------------------------------------------+
//| 最後のポジション情報取得                                          |
//+------------------------------------------------------------------+
bool GetLastPositionInfo(ENUM_POSITION_TYPE type, datetime &out_last_time, double &out_last_price)
{
    datetime last_time  = 0;
    double   last_price = 0;
    bool     found      = false;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetInteger(POSITION_TYPE)  != type) continue;

        datetime t = (datetime)PositionGetInteger(POSITION_TIME);
        if(t > last_time)
        {
            last_time  = t;
            last_price = PositionGetDouble(POSITION_PRICE_OPEN);
            found      = true;
        }
    }
    if(found) { out_last_time = last_time; out_last_price = last_price; }
    return found;
}

//+------------------------------------------------------------------+
//| ポジション数カウント                                              |
//+------------------------------------------------------------------+
int CountPositions(ENUM_POSITION_TYPE type)
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol &&
           PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
           PositionGetInteger(POSITION_TYPE)  == type)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| フィボナッチロット計算                                            |
//+------------------------------------------------------------------+
void CalculateFibonacciLots(double &lots[])
{
    lots[0] = InitialLots;
    if(ArraySize(lots) > 1) lots[1] = InitialLots;
    for(int i = 2; i < ArraySize(lots); i++)
        lots[i] = lots[i-1] + lots[i-2];
}

//+------------------------------------------------------------------+
//| グリッドTP判定・決済                                              |
//+------------------------------------------------------------------+
void CheckAndCloseGrid()
{
    CloseGridIfProfitable(POSITION_TYPE_BUY);
    CloseGridIfProfitable(POSITION_TYPE_SELL);
}

void CloseGridIfProfitable(ENUM_POSITION_TYPE type)
{
    if(CountPositions(type) == 0) return;

    double total_lots    = 0;
    double break_even    = GetBreakEvenPrice(type, total_lots);
    if(break_even == 0) return;

    double ask           = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid           = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double profit_points = TakeProfitPips * _Point * pips_to_points;

    bool should_close = false;
    if(type == POSITION_TYPE_BUY)
        should_close = (bid > break_even + profit_points);
    else
        should_close = (ask < break_even - profit_points);

    if(should_close) CloseAllPositions(type);
}

double GetBreakEvenPrice(ENUM_POSITION_TYPE type, double &total_lots)
{
    double total_cost = 0;
    total_lots = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(PositionGetInteger(POSITION_TYPE)  != type) continue;
        double vol = PositionGetDouble(POSITION_VOLUME);
        total_cost += PositionGetDouble(POSITION_PRICE_OPEN) * vol;
        total_lots += vol;
    }
    return (total_lots > 0) ? total_cost / total_lots : 0;
}

void CloseAllPositions(ENUM_POSITION_TYPE type)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol &&
           PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
           PositionGetInteger(POSITION_TYPE)  == type)
            trade.PositionClose(PositionGetTicket(i));
    }
    if(type == POSITION_TYPE_BUY)  g_trailStopBuy  = 0;
    if(type == POSITION_TYPE_SELL) g_trailStopSell = 0;
}

//+------------------------------------------------------------------+
//| トレーリング判定・実行                                            |
//+------------------------------------------------------------------+
void CheckAndTrailGrid()
{
    if(!UseBreakEvenTrail && !UseDirectTrail) return;
    TrailIfNeeded(POSITION_TYPE_BUY);
    TrailIfNeeded(POSITION_TYPE_SELL);
}

void TrailIfNeeded(ENUM_POSITION_TYPE type)
{
    int count = CountPositions(type);
    if(count < TrailingStartCount) return;

    double totalLots = 0;
    double breakEven = GetBreakEvenPrice(type, totalLots);
    if(breakEven == 0) return;

    double ask           = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid           = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double triggerPoints = TrailingTriggerPips * _Point * pips_to_points;
    double stepPoints    = TrailingStepPips    * _Point * pips_to_points;

    if(type == POSITION_TYPE_BUY)
    {
        bool triggered = false;
        if(UseBreakEvenTrail && bid > breakEven + triggerPoints) triggered = true;
        if(UseDirectTrail    && bid > breakEven + triggerPoints) triggered = true;
        if(!triggered) return;

        double newSL = bid - stepPoints;
        if(newSL > g_trailStopBuy)
        {
            g_trailStopBuy = newSL;
            SetSLForAllPositions(type, g_trailStopBuy);
        }
    }
    else
    {
        bool triggered = false;
        if(UseBreakEvenTrail && ask < breakEven - triggerPoints) triggered = true;
        if(UseDirectTrail    && ask < breakEven - triggerPoints) triggered = true;
        if(!triggered) return;

        double newSL = ask + stepPoints;
        if(g_trailStopSell == 0 || newSL < g_trailStopSell)
        {
            g_trailStopSell = newSL;
            SetSLForAllPositions(type, g_trailStopSell);
        }
    }
}

void SetSLForAllPositions(ENUM_POSITION_TYPE type, double sl)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;
        double tp = PositionGetDouble(POSITION_TP);
        trade.PositionModify(PositionGetTicket(i), sl, tp);
    }
}

//+------------------------------------------------------------------+
//| 未決注文削除                                                      |
//+------------------------------------------------------------------+
void RemovePendingOrders(ENUM_ORDER_TYPE type = WRONG_VALUE)
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(OrderGetInteger(ORDER_MAGIC) == MagicNumber &&
           OrderGetString(ORDER_SYMBOL) == _Symbol)
        {
            if(type == WRONG_VALUE || OrderGetInteger(ORDER_TYPE) == type)
                trade.OrderDelete(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| ロット正規化                                                      |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
    double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    lot = MathRound(lot / step_lot) * step_lot;
    if(lot < min_lot) lot = 0;
    if(lot > max_lot) lot = max_lot;
    return lot;
}
