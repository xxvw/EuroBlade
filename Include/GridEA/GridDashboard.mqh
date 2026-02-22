//+------------------------------------------------------------------+
//|                                             GridDashboard.mqh    |
//|                                    EuroBlade Grid EA Dashboard   |
//+------------------------------------------------------------------+
#property copyright "EuroBlade"
#property strict

//+------------------------------------------------------------------+
//| ダッシュボードクラス                                              |
//+------------------------------------------------------------------+
class CGridDashboard
{
private:
    string   m_prefix;
    int      m_x;
    int      m_y;
    int      m_width;
    bool     m_created;
    bool     m_isJPY;
    bool     m_entryEnabled;
    int      m_magicNumber;

    // ライトモード配色
    color    m_bgColor;
    color    m_panelColor;
    color    m_titleColor;
    color    m_textColor;
    color    m_profitColor;
    color    m_lossColor;
    color    m_btnOnColor;
    color    m_btnOffColor;
    color    m_separatorColor;

    // セクション開始Y座標（動的計算用）
    int      m_lineH;

    //--- 内部ヘルパー ---
    void     CreateBg(string name, int x, int y, int w, int h, color clr, bool back=true);
    void     CreateLabel(string name, int x, int y, string text, color clr, int fs=9, bool bold=false);
    void     SetLabel(string name, string text, color clr);
    void     CreateButton(string name, int x, int y, int w, int h, string text, color bgClr, color txtClr, int fs=9);
    void     SetButton(string name, string text, color bgClr);
    void     DeleteObj(string name);

    string   FormatProfit(double val);
    string   FormatLot(double lot);
    string   FormatTimeLeft(int secs);
    color    GetEventColor(int secs);
    bool     IsSessionActive(int utcHour, int startH, int endH);
    void     CalcWeeklyStats(double &dayProfit[], double &dayDD[], int &dayCount, double &totalProfit, double &profitRate);
    void     GetPositionStats(int &buyCount, double &buyLot, double &buyProfit,
                              int &sellCount, double &sellLot, double &sellProfit);
    void     GetNextEvents(string &names[], string &times[], color &clrs[], int &count, int maxCount);

    // オブジェクト名生成
    string   N(string key) { return m_prefix + key; }

public:
    CGridDashboard();
    ~CGridDashboard() { Destroy(); }

    void     Create(int x, int y, bool isJPY);
    void     Update(int magicNumber, double trailBuy, double trailSell,
                    int trendCur, int trendUpper, int trendLower, bool maEnabled);
    void     SetEntryEnabled(bool enabled);
    void     Destroy();
};

//+------------------------------------------------------------------+
//| コンストラクタ                                                    |
//+------------------------------------------------------------------+
CGridDashboard::CGridDashboard()
{
    m_prefix        = "GD_";
    m_x             = 20;
    m_y             = 30;
    m_width         = 260;
    m_created       = false;
    m_isJPY         = false;
    m_entryEnabled  = true;
    m_magicNumber   = 0;
    m_lineH         = 17;

    // ライトモード色
    m_bgColor        = C'245,245,248';
    m_panelColor     = C'225,225,235';
    m_titleColor     = C'40,40,100';
    m_textColor      = clrBlack;
    m_profitColor    = C'0,120,0';
    m_lossColor      = C'180,0,0';
    m_btnOnColor     = C'0,140,0';
    m_btnOffColor    = C'180,0,0';
    m_separatorColor = C'180,180,200';
}

//+------------------------------------------------------------------+
//| ダッシュボード作成                                                |
//+------------------------------------------------------------------+
void CGridDashboard::Create(int x, int y, bool isJPY)
{
    m_x     = x;
    m_y     = y;
    m_isJPY = isJPY;

    // 背景全体（高さは行数から計算: セクション5つ x 平均行数）
    int totalH = 470;
    CreateBg(N("BgMain"), m_x, m_y, m_width, totalH, m_bgColor);

    int lx  = m_x + 8;
    int rx  = m_x + m_width - 8;
    int cy  = m_y + 6;

    //--- ヘッダー ---
    CreateBg(N("BgHeader"), m_x, cy - 2, m_width, 28, m_panelColor);
    CreateLabel(N("Title"), lx, cy + 4, "EuroBlade", m_titleColor, 11, true);
    CreateLabel(N("Symbol"), lx + 95, cy + 4, _Symbol, m_titleColor, 10, false);
    // エントリーボタン（右寄せ）
    CreateButton(N("BtnEntry"), rx - 72, cy, 70, 20, "新規: ON", m_btnOnColor, clrWhite, 8);
    cy += 32;

    //--- セッション ---
    CreateBg(N("BgSess"), m_x, cy - 2, m_width, 2, m_separatorColor);
    cy += 4;
    CreateLabel(N("SessTitle"), lx, cy, "■ セッション", m_titleColor, 8, true);
    cy += m_lineH;
    CreateLabel(N("SessWLbl"), lx,      cy, "Wellington", m_textColor, 8);
    CreateLabel(N("SessWTime"), lx+75,  cy, "21:00-06:00(UTC)", C'140,140,140', 8);
    CreateLabel(N("SessWStat"), rx-30,  cy, "closed", C'160,160,160', 8);
    cy += m_lineH;
    CreateLabel(N("SessTLbl"), lx,      cy, "Tokyo",      m_textColor, 8);
    CreateLabel(N("SessTTime"), lx+75,  cy, "00:00-09:00(UTC)", C'140,140,140', 8);
    CreateLabel(N("SessTStat"), rx-30,  cy, "closed", C'160,160,160', 8);
    cy += m_lineH;
    CreateLabel(N("SessLLbl"), lx,      cy, "London",     m_textColor, 8);
    CreateLabel(N("SessLTime"), lx+75,  cy, "07:00-16:00(UTC)", C'140,140,140', 8);
    CreateLabel(N("SessLStat"), rx-30,  cy, "closed", C'160,160,160', 8);
    cy += m_lineH;
    CreateLabel(N("SessNLbl"), lx,      cy, "New York",   m_textColor, 8);
    CreateLabel(N("SessNTime"), lx+75,  cy, "12:00-21:00(UTC)", C'140,140,140', 8);
    CreateLabel(N("SessNStat"), rx-30,  cy, "closed", C'160,160,160', 8);
    cy += m_lineH + 4;

    //--- ポジション状況 ---
    CreateBg(N("BgPos"), m_x, cy - 2, m_width, 2, m_separatorColor);
    cy += 4;
    CreateLabel(N("PosTitle"), lx, cy, "■ ポジション", m_titleColor, 8, true);
    cy += m_lineH;
    // ヘッダー行
    CreateLabel(N("PosH1"), lx,      cy, "方向", C'100,100,120', 8);
    CreateLabel(N("PosH2"), lx+45,   cy, "枚数", C'100,100,120', 8);
    CreateLabel(N("PosH3"), lx+90,   cy, "Lot",  C'100,100,120', 8);
    CreateLabel(N("PosH4"), lx+140,  cy, "損益",  C'100,100,120', 8);
    cy += m_lineH - 2;
    CreateLabel(N("PosBuyLbl"),  lx,     cy, "BUY",  m_profitColor, 8, true);
    CreateLabel(N("PosBuyCnt"),  lx+45,  cy, "0",    m_textColor, 8);
    CreateLabel(N("PosBuyLot"),  lx+90,  cy, "0.00", m_textColor, 8);
    CreateLabel(N("PosBuyPnl"),  lx+140, cy, "---",  m_textColor, 8);
    cy += m_lineH - 2;
    CreateLabel(N("PosSellLbl"), lx,     cy, "SELL", m_lossColor, 8, true);
    CreateLabel(N("PosSellCnt"), lx+45,  cy, "0",    m_textColor, 8);
    CreateLabel(N("PosSellLot"), lx+90,  cy, "0.00", m_textColor, 8);
    CreateLabel(N("PosSellPnl"), lx+140, cy, "---",  m_textColor, 8);
    cy += m_lineH - 2;
    CreateLabel(N("PosTotLbl"),  lx,     cy, "合計", m_titleColor, 8, true);
    CreateLabel(N("PosTotLot"),  lx+90,  cy, "0.00", m_textColor, 8);
    CreateLabel(N("PosTotPnl"),  lx+140, cy, "---",  m_textColor, 8);
    cy += m_lineH + 4;

    //--- 今週のサマリー ---
    CreateBg(N("BgWeek"), m_x, cy - 2, m_width, 2, m_separatorColor);
    cy += 4;
    CreateLabel(N("WeekTitle"), lx, cy, "■ 今週のサマリー", m_titleColor, 8, true);
    cy += m_lineH;
    string dayNames[] = {"月","火","水","木","金","土","日"};
    for(int i = 0; i < 7; i++)
    {
        string key = "Day" + IntegerToString(i);
        CreateLabel(N(key+"Lbl"), lx,      cy, dayNames[i], C'100,100,120', 8);
        CreateLabel(N(key+"Pnl"), lx+25,   cy, "---",       m_textColor, 8);
        CreateLabel(N(key+"DD"),  lx+140,  cy, "",          C'140,140,140', 8);
        cy += m_lineH - 2;
    }
    CreateLabel(N("WeekTotLbl"),  lx,     cy, "総損益",  m_titleColor, 8, true);
    CreateLabel(N("WeekTotPnl"),  lx+50,  cy, "---",    m_textColor, 8);
    CreateLabel(N("WeekRateLbl"), lx+140, cy, "利率:",  C'100,100,120', 8);
    CreateLabel(N("WeekRate"),    lx+165, cy, "---",    m_textColor, 8);
    cy += m_lineH + 4;

    //--- トレーリング & MA ---
    CreateBg(N("BgTrailMA"), m_x, cy - 2, m_width, 2, m_separatorColor);
    cy += 4;
    CreateLabel(N("TrailTitle"), lx, cy, "■ トレーリング / MAフィルター", m_titleColor, 8, true);
    cy += m_lineH;
    CreateLabel(N("TrailBuyLbl"),  lx,     cy, "Trail BUY:",  C'100,100,120', 8);
    CreateLabel(N("TrailBuyVal"),  lx+75,  cy, "---",         C'140,140,140', 8);
    cy += m_lineH - 2;
    CreateLabel(N("TrailSellLbl"), lx,     cy, "Trail SELL:", C'100,100,120', 8);
    CreateLabel(N("TrailSellVal"), lx+75,  cy, "---",         C'140,140,140', 8);
    cy += m_lineH;
    CreateLabel(N("MACurLbl"),   lx,      cy, "MA現在足:", C'100,100,120', 8);
    CreateLabel(N("MACurVal"),   lx+75,   cy, "---",       C'140,140,140', 8);
    CreateLabel(N("MAUpLbl"),    lx+110,  cy, "上位:",     C'100,100,120', 8);
    CreateLabel(N("MAUpVal"),    lx+140,  cy, "---",       C'140,140,140', 8);
    CreateLabel(N("MALowLbl"),   lx+170,  cy, "下位:",     C'100,100,120', 8);
    CreateLabel(N("MALowVal"),   lx+200,  cy, "---",       C'140,140,140', 8);
    cy += m_lineH + 4;

    //--- 直近の大型指標 ---
    CreateBg(N("BgCal"), m_x, cy - 2, m_width, 2, m_separatorColor);
    cy += 4;
    CreateLabel(N("CalTitle"), lx, cy, "■ 直近の大型指標 (★★★)", m_titleColor, 8, true);
    cy += m_lineH;
    for(int i = 0; i < 5; i++)
    {
        string key = "Cal" + IntegerToString(i);
        CreateLabel(N(key+"Name"), lx,      cy, "", m_textColor, 8);
        CreateLabel(N(key+"Time"), lx+100,  cy, "", C'140,140,140', 8);
        cy += m_lineH - 2;
    }

    m_created = true;
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| ダッシュボード更新（1分ごとに呼ぶ）                              |
//+------------------------------------------------------------------+
void CGridDashboard::Update(int magicNumber, double trailBuy, double trailSell,
                            int trendCur, int trendUpper, int trendLower, bool maEnabled)
{
    if(!m_created) return;
    m_magicNumber = magicNumber;

    //--- セッション更新 ---
    MqlDateTime dt;
    TimeToStruct(TimeGMT(), dt);
    int utcH = dt.hour;

    // Wellington: 21:00-06:00 UTC（日またぎ）
    bool wOpen = IsSessionActive(utcH, 21, 6);
    // Tokyo:      00:00-09:00 UTC
    bool tOpen = IsSessionActive(utcH, 0, 9);
    // London:     07:00-16:00 UTC
    bool lOpen = IsSessionActive(utcH, 7, 16);
    // New York:   12:00-21:00 UTC
    bool nOpen = IsSessionActive(utcH, 12, 21);

    color wCol = wOpen ? C'0,130,0'   : C'160,160,160';
    color tCol = tOpen ? C'0,80,180'  : C'160,160,160';
    color lCol = lOpen ? C'160,90,0'  : C'160,160,160';
    color nCol = nOpen ? C'180,0,0'   : C'160,160,160';

    SetLabel(N("SessWStat"), wOpen ? "● OPEN" : "○ closed", wCol);
    SetLabel(N("SessTStat"), tOpen ? "● OPEN" : "○ closed", tCol);
    SetLabel(N("SessLStat"), lOpen ? "● OPEN" : "○ closed", lCol);
    SetLabel(N("SessNStat"), nOpen ? "● OPEN" : "○ closed", nCol);

    //--- ポジション状況更新 ---
    int    buyCount,  sellCount;
    double buyLot,    sellLot;
    double buyProfit, sellProfit;
    GetPositionStats(buyCount, buyLot, buyProfit, sellCount, sellLot, sellProfit);

    double totLot    = buyLot + sellLot;
    double totProfit = buyProfit + sellProfit;

    color bPnlCol = buyProfit  >= 0 ? m_profitColor : m_lossColor;
    color sPnlCol = sellProfit >= 0 ? m_profitColor : m_lossColor;
    color tPnlCol = totProfit  >= 0 ? m_profitColor : m_lossColor;

    SetLabel(N("PosBuyCnt"),  IntegerToString(buyCount),  m_textColor);
    SetLabel(N("PosBuyLot"),  FormatLot(buyLot),          m_textColor);
    SetLabel(N("PosBuyPnl"),  FormatProfit(buyProfit),    bPnlCol);
    SetLabel(N("PosSellCnt"), IntegerToString(sellCount), m_textColor);
    SetLabel(N("PosSellLot"), FormatLot(sellLot),         m_textColor);
    SetLabel(N("PosSellPnl"), FormatProfit(sellProfit),   sPnlCol);
    SetLabel(N("PosTotLot"),  FormatLot(totLot),          m_textColor);
    SetLabel(N("PosTotPnl"),  FormatProfit(totProfit),    tPnlCol);

    //--- 週次サマリー更新 ---
    double dayProfit[7], dayDD[7];
    int    dayCount;
    double totalProfit, profitRate;
    CalcWeeklyStats(dayProfit, dayDD, dayCount, totalProfit, profitRate);

    string dayNames[] = {"月","火","水","木","金","土","日"};
    MqlDateTime today;
    TimeToStruct(TimeCurrent(), today);
    // MT5のdow: 0=日,1=月...6=土 → 配列インデックス: 月=0..日=6
    int todayIdx = (today.day_of_week == 0) ? 6 : today.day_of_week - 1;

    for(int i = 0; i < 7; i++)
    {
        string key  = "Day" + IntegerToString(i);
        string pnlStr, ddStr;
        color  pnlCol;

        if(i == todayIdx)
        {
            pnlStr = FormatProfit(dayProfit[i]) + " (本日)";
            ddStr  = dayDD[i] < 0 ? StringFormat("DD:%.2f%%", dayDD[i]) : "";
        }
        else if(dayProfit[i] == 0 && dayDD[i] == 0)
        {
            pnlStr = "---";
            ddStr  = "";
        }
        else
        {
            pnlStr = FormatProfit(dayProfit[i]);
            ddStr  = dayDD[i] < 0 ? StringFormat("DD:%.2f%%", dayDD[i]) : "";
        }

        pnlCol = dayProfit[i] >= 0 ? m_profitColor : m_lossColor;
        SetLabel(N(key+"Pnl"), pnlStr, pnlCol);
        SetLabel(N(key+"DD"),  ddStr,  C'140,140,140');
    }

    color totCol  = totalProfit >= 0 ? m_profitColor : m_lossColor;
    color rateCol = profitRate  >= 0 ? m_profitColor : m_lossColor;
    SetLabel(N("WeekTotPnl"), FormatProfit(totalProfit), totCol);
    SetLabel(N("WeekRate"),   StringFormat("%+.2f%%", profitRate), rateCol);

    //--- トレーリング & MA更新 ---
    if(trailBuy > 0)
        SetLabel(N("TrailBuyVal"),  DoubleToString(trailBuy, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), m_profitColor);
    else
        SetLabel(N("TrailBuyVal"),  "---", C'140,140,140');

    if(trailSell > 0)
        SetLabel(N("TrailSellVal"), DoubleToString(trailSell, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), m_lossColor);
    else
        SetLabel(N("TrailSellVal"), "---", C'140,140,140');

    if(maEnabled)
    {
        SetLabel(N("MACurVal"), trendCur > 0 ? "↑" : (trendCur < 0 ? "↓" : "-"),
                 trendCur > 0 ? m_profitColor : (trendCur < 0 ? m_lossColor : C'140,140,140'));
        SetLabel(N("MAUpVal"),  trendUpper > 0 ? "↑" : (trendUpper < 0 ? "↓" : "-"),
                 trendUpper > 0 ? m_profitColor : (trendUpper < 0 ? m_lossColor : C'140,140,140'));
        SetLabel(N("MALowVal"), trendLower > 0 ? "↑" : (trendLower < 0 ? "↓" : "-"),
                 trendLower > 0 ? m_profitColor : (trendLower < 0 ? m_lossColor : C'140,140,140'));
    }
    else
    {
        SetLabel(N("MACurVal"), "OFF", C'140,140,140');
        SetLabel(N("MAUpVal"),  "OFF", C'140,140,140');
        SetLabel(N("MALowVal"), "OFF", C'140,140,140');
    }

    //--- 経済指標更新 ---
    string evNames[5], evTimes[5];
    color  evColors[5];
    int    evCount = 0;
    GetNextEvents(evNames, evTimes, evColors, evCount, 5);

    for(int i = 0; i < 5; i++)
    {
        string key = "Cal" + IntegerToString(i);
        if(i < evCount)
        {
            SetLabel(N(key+"Name"), evNames[i], m_textColor);
            SetLabel(N(key+"Time"), evTimes[i], evColors[i]);
        }
        else
        {
            SetLabel(N(key+"Name"), "", m_textColor);
            SetLabel(N(key+"Time"), "", m_textColor);
        }
    }

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| エントリーON/OFFボタン更新                                       |
//+------------------------------------------------------------------+
void CGridDashboard::SetEntryEnabled(bool enabled)
{
    m_entryEnabled = enabled;
    if(!m_created) return;
    if(enabled)
        SetButton(N("BtnEntry"), "新規: ON",  m_btnOnColor);
    else
        SetButton(N("BtnEntry"), "新規: OFF", m_btnOffColor);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| ダッシュボード破棄                                                |
//+------------------------------------------------------------------+
void CGridDashboard::Destroy()
{
    if(!m_created) return;

    string keys[] = {
        "BgMain","BgHeader","Title","Symbol","BtnEntry",
        "BgSess","SessTitle",
        "SessWLbl","SessWTime","SessWStat",
        "SessTLbl","SessTTime","SessTStat",
        "SessLLbl","SessLTime","SessLStat",
        "SessNLbl","SessNTime","SessNStat",
        "BgPos","PosTitle",
        "PosH1","PosH2","PosH3","PosH4",
        "PosBuyLbl","PosBuyCnt","PosBuyLot","PosBuyPnl",
        "PosSellLbl","PosSellCnt","PosSellLot","PosSellPnl",
        "PosTotLbl","PosTotLot","PosTotPnl",
        "BgWeek","WeekTitle",
        "WeekTotLbl","WeekTotPnl","WeekRateLbl","WeekRate",
        "BgTrailMA","TrailTitle",
        "TrailBuyLbl","TrailBuyVal","TrailSellLbl","TrailSellVal",
        "MACurLbl","MACurVal","MAUpLbl","MAUpVal","MALowLbl","MALowVal",
        "BgCal","CalTitle",
        "GD_Icon"
    };

    for(int i = 0; i < ArraySize(keys); i++)
        DeleteObj(N(keys[i]));

    string dayNames[] = {"Mon","Tue","Wed","Thu","Fri","Sat","Sun"};
    for(int i = 0; i < 7; i++)
    {
        string key = "Day" + IntegerToString(i);
        DeleteObj(N(key+"Lbl"));
        DeleteObj(N(key+"Pnl"));
        DeleteObj(N(key+"DD"));
    }
    for(int i = 0; i < 5; i++)
    {
        string key = "Cal" + IntegerToString(i);
        DeleteObj(N(key+"Name"));
        DeleteObj(N(key+"Time"));
    }

    // アイコン
    ObjectDelete(0, "GD_Icon");

    m_created = false;
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| セッション判定（日またぎ対応）                                    |
//+------------------------------------------------------------------+
bool CGridDashboard::IsSessionActive(int utcHour, int startH, int endH)
{
    if(startH < endH)
        return (utcHour >= startH && utcHour < endH);
    else // 日またぎ (例: 21-06)
        return (utcHour >= startH || utcHour < endH);
}

//+------------------------------------------------------------------+
//| ポジション集計                                                    |
//+------------------------------------------------------------------+
void CGridDashboard::GetPositionStats(int &buyCount, double &buyLot, double &buyProfit,
                                      int &sellCount, double &sellLot, double &sellProfit)
{
    buyCount  = 0; buyLot  = 0; buyProfit  = 0;
    sellCount = 0; sellLot = 0; sellProfit = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) != _Symbol) continue;
        if(m_magicNumber > 0 && PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;
        ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double vol  = PositionGetDouble(POSITION_VOLUME);
        double pnl  = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

        if(pt == POSITION_TYPE_BUY)
        {
            buyCount++;
            buyLot    += vol;
            buyProfit += pnl;
        }
        else
        {
            sellCount++;
            sellLot    += vol;
            sellProfit += pnl;
        }
    }
}

//+------------------------------------------------------------------+
//| 今週の日別損益・DDを集計（MagicNumberで絞り込み）                |
//+------------------------------------------------------------------+
void CGridDashboard::CalcWeeklyStats(double &dayProfit[], double &dayDD[], int &dayCount,
                                     double &totalProfit, double &profitRate)
{
    ArrayInitialize(dayProfit, 0);
    ArrayInitialize(dayDD, 0);
    dayCount    = 0;
    totalProfit = 0;
    profitRate  = 0;

    // 今週月曜0:00を計算
    MqlDateTime now;
    TimeToStruct(TimeCurrent(), now);
    int dow = now.day_of_week; // 0=日,1=月...6=土
    int daysFromMon = (dow == 0) ? 6 : dow - 1;
    datetime weekStart = TimeCurrent() - daysFromMon * 86400;
    MqlDateTime ws;
    TimeToStruct(weekStart, ws);
    ws.hour = 0; ws.min = 0; ws.sec = 0;
    weekStart = StructToTime(ws);

    if(!HistorySelect(weekStart, TimeCurrent())) return;

    int total = HistoryDealsTotal();
    for(int i = 0; i < total; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket == 0) continue;
        if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
        if(m_magicNumber > 0 && HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magicNumber) continue;

        ENUM_DEAL_TYPE dtype = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
        if(dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL) continue;

        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                      + HistoryDealGetDouble(ticket, DEAL_SWAP)
                      + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        datetime dtime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

        MqlDateTime dt;
        TimeToStruct(dtime, dt);
        int dw = dt.day_of_week;
        int idx = (dw == 0) ? 6 : dw - 1; // 月=0..日=6

        dayProfit[idx] += profit;
        totalProfit    += profit;
        dayCount++;

        // DD: その日の累積マイナス分
        if(dayProfit[idx] < dayDD[idx])
            dayDD[idx] = dayProfit[idx];
    }

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(balance > 0.01)
        profitRate = totalProfit / balance * 100.0;

    // DDをパーセント変換
    for(int i = 0; i < 7; i++)
    {
        if(dayDD[i] < 0 && balance > 0.01)
            dayDD[i] = dayDD[i] / balance * 100.0;
        else
            dayDD[i] = 0;
    }
}

//+------------------------------------------------------------------+
//| 直近の高重要度指標を取得（最大maxCount件、近い順）               |
//+------------------------------------------------------------------+
void CGridDashboard::GetNextEvents(string &names[], string &times[], color &clrs[], int &count, int maxCount)
{
    ArrayResize(names, maxCount);
    ArrayResize(times, maxCount);
    ArrayResize(clrs,  maxCount);
    count = 0;

    MqlCalendarValue values[];
    datetime now  = TimeCurrent();
    datetime to   = now + 7 * 86400;

    int total = CalendarValueHistory(values, now, to);
    if(total <= 0) return;

    // イベントを時刻順にソートするため並べ替え（最大5件）
    for(int i = 0; i < total && count < maxCount; i++)
    {
        MqlCalendarEvent ev;
        if(!CalendarEventById(values[i].event_id, ev)) continue;
        if(ev.importance != CALENDAR_IMPORTANCE_HIGH)  continue;

        datetime evTime = values[i].time;
        if(evTime <= now) continue;

        int secsLeft = (int)(evTime - now);

        MqlCalendarCountry country;
        CalendarCountryById(ev.country_id, country);

        names[count] = country.currency + " " + ev.name;
        if(StringLen(names[count]) > 28)
            names[count] = StringSubstr(names[count], 0, 25) + "...";

        times[count] = FormatTimeLeft(secsLeft);
        clrs[count]  = GetEventColor(secsLeft);
        count++;
    }
}

//+------------------------------------------------------------------+
//| 残り時間フォーマット                                              |
//+------------------------------------------------------------------+
string CGridDashboard::FormatTimeLeft(int secs)
{
    if(secs <= 0) return "発表中";
    int d = secs / 86400;
    int h = (secs % 86400) / 3600;
    int m = (secs % 3600) / 60;

    if(d > 0) return StringFormat("%d日%d時間%d分後", d, h, m);
    if(h > 0) return StringFormat("%d時間%d分後", h, m);
    if(m > 0) return StringFormat("%d分後", m);
    return "1分未満";
}

//+------------------------------------------------------------------+
//| 残り時間による色取得（7段階）                                     |
//+------------------------------------------------------------------+
color CGridDashboard::GetEventColor(int secs)
{
    if(secs >= 86400)      return C'160,160,160';  // 1日以上: 薄グレー
    if(secs >= 43200)      return C'100,100,100';  // 12時間以上: グレー
    if(secs >= 10800)      return C'180,120,0';    // 3時間以上: ダークゴールド
    if(secs >= 3600)       return C'200,80,0';     // 1時間以上: ダークオレンジ
    if(secs >= 900)        return C'180,0,0';      // 15分以上: ダークレッド
    if(secs >= 180)        return C'220,0,0';      // 3分以上: レッド
    return                        C'255,0,0';      // 1分未満: 鮮明レッド
}

//+------------------------------------------------------------------+
//| 損益フォーマット（JPY: 整数、その他: 小数2桁）                   |
//+------------------------------------------------------------------+
string CGridDashboard::FormatProfit(double val)
{
    if(m_isJPY)
        return StringFormat("%+.0f JPY", val);
    return StringFormat("%+.2f USD", val);
}

//+------------------------------------------------------------------+
//| ロットフォーマット                                                |
//+------------------------------------------------------------------+
string CGridDashboard::FormatLot(double lot)
{
    return StringFormat("%.2f lot", lot);
}

//+------------------------------------------------------------------+
//| 背景矩形作成                                                      |
//+------------------------------------------------------------------+
void CGridDashboard::CreateBg(string name, int x, int y, int w, int h, color clr, bool back=true)
{
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE,      w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE,      h);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    clr);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_BACK,       back);
}

//+------------------------------------------------------------------+
//| ラベル作成                                                        |
//+------------------------------------------------------------------+
void CGridDashboard::CreateLabel(string name, int x, int y, string text, color clr, int fs=9, bool bold=false)
{
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
    ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
    ObjectSetString(0,  name, OBJPROP_TEXT,       text);
    ObjectSetString(0,  name, OBJPROP_FONT,       bold ? "Arial Bold" : "Arial");
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fs);
    ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| ラベルテキスト・色更新                                            |
//+------------------------------------------------------------------+
void CGridDashboard::SetLabel(string name, string text, color clr)
{
    ObjectSetString(0,  name, OBJPROP_TEXT,  text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| ボタン作成                                                        |
//+------------------------------------------------------------------+
void CGridDashboard::CreateButton(string name, int x, int y, int w, int h,
                                  string text, color bgClr, color txtClr, int fs=9)
{
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE,      w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE,      h);
    ObjectSetString(0,  name, OBJPROP_TEXT,       text);
    ObjectSetString(0,  name, OBJPROP_FONT,       "Arial Bold");
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fs);
    ObjectSetInteger(0, name, OBJPROP_COLOR,      txtClr);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    bgClr);
    ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| ボタンテキスト・色更新                                            |
//+------------------------------------------------------------------+
void CGridDashboard::SetButton(string name, string text, color bgClr)
{
    ObjectSetString(0,  name, OBJPROP_TEXT,    text);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
    ObjectSetInteger(0, name, OBJPROP_STATE,   false);
}

//+------------------------------------------------------------------+
//| オブジェクト削除                                                  |
//+------------------------------------------------------------------+
void CGridDashboard::DeleteObj(string name)
{
    ObjectDelete(0, name);
}
//+------------------------------------------------------------------+
