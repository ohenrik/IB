//+------------------------------------------------------------------+
//|                                                         IBv1.mq4 |
//|                                             Ole Henrik Skogstrøm |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Ole Henrik Skogstrøm"
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

datetime lastBarOpenTime;
int current_ticket=0;

extern int     Magic=1;
extern double  Risk=0.01;
extern int     SL = 50;
extern int     TP = 100;
extern int     MA_period=200;
extern double  LotSizeInput=0.01;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
  {
//---

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   string bar_type;

   static int  ticket=0;

   if(IsNewBar())
     {
      bar_type=BarType(1);

      if(bar_type=="IBup")
        {
         DrawArrowUp("Up"+IntegerToString(Time[1]),High[1]+200*Point,Green,1);
        }

      if(bar_type=="IBdown")
        {
         DrawArrowDown("Down"+IntegerToString(Time[1]),High[1]+200*Point,Green,1);
        }

     }

  }
//+------------------------------------------------------------------+

int FindTicket(int M)
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      bool res;
      res=OrderSelect(i,SELECT_BY_POS);
      if(res==true)
        {
         if(OrderMagicNumber()==M)
           {
            current_ticket=OrderTicket();
            break;
           }
        }
     }
   return(FALSE);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime thisBarOpenTime=Time[0];
   if(thisBarOpenTime!=lastBarOpenTime)
     {
      lastBarOpenTime=thisBarOpenTime;
      return (true);
        } else {
      return (false);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string BarType(int index)
  {
   bool inside_bar=(High[index+1]>High[index]) && (Low[index+1]<Low[index]);
   bool up_trend=(Close[index+1]>Close[index+2]) && (Open[index+2]<Close[index+2]);
   bool down_trend=(Close[index+1]<Close[index+2]) && (Open[index+2]>Close[index+2]);

// Need to recognize
// 1. IB must trade through or test the 3 EMA. Helpfull if more of the 3 bars thouch or trade through the 3 EMA
// 2. The difference between 3 and 6 EMA (MACD) must contract on the IB. So that 3EMA[0] - 6EMA[0] < 3EMA[1] - 6EMA[1]. We need a contraction!
// 3. We want to see Expantion of the MACD from index + 2 (point 2) to index +1 (point 1). So the two bars before the IB must have a positive trend also on the MACD
// 4. We need to be sure that the contraction is the first since 3 EMA crossed the 6 EMA. OR. Highest High on MACD since it crossed. So first up-move.
// (video 5)

// To recognize momentum look at these signs:
// 1. 4 or 5 higher highs (or LL) preceeding the IB.
// (video 6))

// Entry point (video 7)
// Start at point 1 +- 3 points
// SL at IB oposite +-5 points
// Watch again! Important for position sizing and so on.


// 1. IB must trade through or test the 3 EMA
   bool ib_touch_3_ema=ThouchCheck(index);
//bool point1_touch_3_ema = thouch_check(index + 1); // Amplifyer 1, (optional)
//bool point2_touch_3_ema = thouch_check(index + 2); // Amplifyer 2, (optional)

// 2. The difference between 3 and 6 EMA (MACD) must contract on the IB. So that 3EMA[0] - 6EMA[0] < 3EMA[1] - 6EMA[1]. We need a contraction!
   bool contraction=ContractionCheck(index);

// 3. We want to see Expantion of the MACD from index + 2 (point 2) to index +1 (point 1). So the two bars before the IB must have a positive trend also on the MACD
   bool expantion_point1_pont2=ExpantionCheck(index);

   bool first_contraction=FirstContraction(index+1);
   bool peak_macd=PeakMACD(index+1);

   if(inside_bar && up_trend && ib_touch_3_ema && contraction && expantion_point1_pont2 && (first_contraction || peak_macd) )
     {
      return "IBup";
     }
   else if(inside_bar && down_trend && ib_touch_3_ema && contraction && expantion_point1_pont2 && (first_contraction || peak_macd))
     {
      return "IBdown";
     }
   else
     {
      return "nothing";
     }

  }
//+------------------------------------------------------------------+
//|  Touch EMA3, this checks requirement 1.                          |
//+------------------------------------------------------------------+
bool ThouchCheck(int index)
  {
   double ema_3=iMA(Symbol(),Period(),3,0,MODE_EMA,PRICE_CLOSE,index);
//printf("High: "+DoubleToStr(High[index])+", EMA3: "+DoubleToStr(ema_3)+"Low: "+DoubleToStr(Low[index]));

   if(ema_3>=Low[index] && ema_3<=High[index])
     {
      return true;
     }
   else
     {
      return false;
     }
  }
//+------------------------------------------------------------------+
//|  Contraction check, requerement 2.                               |
//+------------------------------------------------------------------+
// 2. The difference between 3 and 6 EMA (MACD) must contract on the IB. So that 3EMA[0] - 6EMA[0] < 3EMA[1] - 6EMA[1]. We need a contraction!
// Remember the oposite for down trends!
bool ContractionCheck(int index)
  {

   string ema_sign=EMA_sign(index);

   double macd=MACD(index);
   double macd_point1=MACD(index+1);

// First identify up or down micro trend.
   if(ema_sign=="positive") // Up-trend
     {
      if(macd<macd_point1)
        {
         return true;
        }
      else
        {
         return false;
        }
     }
   else if(ema_sign=="negative") // Down-trend
     {
      if(macd>macd_point1)
        {
         return true;
        }
      else
        {
         return false;
        }
     }
   else // Equal ema 3 and 6, should return no trend
     {
      return false;
     }
  }
//+------------------------------------------------------------------+
//|  Expantion check, checks if we have an uptrend right before      |
//+------------------------------------------------------------------+
// 3. We want to see Expantion of the MACD from index + 2 (point 2) to index +1 (point 1). So the two bars before the IB must have a positive trend also on the MACD
bool ExpantionCheck(int index)
  {
   string ema_sign=EMA_sign(index+1);

   double macd_point1= MACD(index+1);
   double macd_point2= MACD(index+2);

   if(ema_sign=="positive")
     {
      if(macd_point1>macd_point2)
        {
         return true;
        }
      else
        {
         return false;
        }
     }
   else if(ema_sign=="negative")
     {
      if(macd_point1<macd_point2)
        {
         return true;
        }
      else
        {
         return false;
        }
     }
   else
     {
      return false;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// 4a. We need to be sure that the contraction is the first since 3 EMA crossed the 6 EMA.
bool FirstContraction(int index)
  {

   string ema_sign=EMA_sign(index);
   int i=index;

   while(EMA_sign(i)==ema_sign)
     {
      if(ContractionCheck(i)==true)
        {
         return false;
        }
      i++;
     }
   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// 4b. OR. Highest High on MACD since it crossed.
bool PeakMACD(int index)
  {

   string ema_sign=EMA_sign(index);
   int i=index;
   double start_macd=MathAbs(MACD(index));

   while(EMA_sign(i)==ema_sign)
     {
      if(start_macd<MathAbs(MACD(i)))
        {
         return false;
        }
      i++;
     }
   return true;
  }
//+------------------------------------------------------------------+
//| MACD                                                             |
//+------------------------------------------------------------------+
double MACD(int index)
  {
   double ema_3=iMA(Symbol(),Period(),3,0,MODE_EMA,PRICE_CLOSE,index);
   double ema_6=iMA(Symbol(),Period(),6,0,MODE_EMA,PRICE_CLOSE,index);

   double macd=(ema_3-ema_6);

   return macd;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string EMA_sign(int index)
  {
   double ema_3=iMA(Symbol(),Period(),3,0,MODE_EMA,PRICE_CLOSE,index);
   double ema_6=iMA(Symbol(),Period(),6,0,MODE_EMA,PRICE_CLOSE,index);

   if(ema_3>ema_6)
     {
      return "positive";
     }
   else if(ema_3<ema_6)
     {
      return "negative";
     }
   else
     {
      return "equal";
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawArrowUp(string ArrowName,double LinePrice,color LineColor,int ArrowTime)
  {
   ObjectCreate(ArrowName,OBJ_ARROW,0,Time[ArrowTime],LinePrice); //draw an up arrow
   ObjectSet(ArrowName,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSet(ArrowName,OBJPROP_ARROWCODE,233); //SYMBOL_ARROWUP
   ObjectSet(ArrowName,OBJPROP_COLOR,LineColor);
   ObjectSet(ArrowName,OBJPROP_FILL,LineColor);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawArrowDown(string ArrowName,double LinePrice,color LineColor,int ArrowTime)
  {
   ObjectCreate(ArrowName,OBJ_ARROW,0,Time[ArrowTime],LinePrice); //draw a down arrow
   ObjectSet(ArrowName,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSet(ArrowName,OBJPROP_ARROWCODE,234); //SYMBOL_ARROWDOWN
   ObjectSet(ArrowName,OBJPROP_COLOR,LineColor);
   ObjectSet(ArrowName,OBJPROP_FILL,LineColor);
  }
//+------------------------------------------------------------------+
