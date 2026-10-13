package com.edtatevosiani99.oldracing

import android.app.Activity
import android.os.Bundle
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
        setContentView(RacingView(this))
    }
}

private data class TrafficCar(var lane: Int, var progress: Float, var color: Int)

private class RacingView(context: Context) : View(context) {
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rnd = Random(System.currentTimeMillis())
    private val traffic = mutableListOf<TrafficCar>()
    private val carColors = intArrayOf(Color.rgb(205,35,40), Color.rgb(35,110,220), Color.rgb(225,225,230))
    private val carNames = arrayOf("MUSTANG GT", "BMW M4", "OPEL ASTRA GTC")
    private val trafficColors = intArrayOf(Color.LTGRAY, Color.rgb(30,30,35), Color.rgb(225,180,35), Color.rgb(30,135,90), Color.WHITE)
    private var playerLane = 1
    private var speed = 105
    private var distance = 0f
    private var crashed = false
    private var twoWay = true
    private var selectedCar = 0
    private var menu = true
    private var spawnClock = 0f
    private var lastTime = System.currentTimeMillis()

    private fun paint(c: Int) { p.color = c; p.style = Paint.Style.FILL; p.strokeWidth = 1f }
    private fun label(c: Canvas, s: String, x: Float, y: Float, size: Float, col: Int = Color.WHITE, center: Boolean = false) {
        paint(col); p.textSize = size
        p.typeface = android.graphics.Typeface.create("sans-serif-condensed", android.graphics.Typeface.BOLD)
        p.textAlign = if (center) Paint.Align.CENTER else Paint.Align.LEFT
        c.drawText(s, x, y, p)
    }

    override fun onDraw(c: Canvas) {
        super.onDraw(c)
        val w = width.toFloat(); val h = height.toFloat()
        val now = System.currentTimeMillis()
        val dt = min(0.05f, (now-lastTime)/1000f); lastTime = now
        c.drawColor(Color.rgb(125,190,230))
        paint(Color.rgb(65,145,70)); c.drawRect(0f,h*0.28f,w,h,p)
        paint(Color.rgb(105,150,160))
        for (i in 0..12) { val x=i*w/12f; c.drawRect(x,h*0.24f+(i%3)*h*0.02f,x+w*0.035f,h*0.36f,p) }
        val road = Path().apply { moveTo(w*.36f,h*.28f); lineTo(w*.64f,h*.28f); lineTo(w*.91f,h); lineTo(w*.09f,h); close() }
        paint(Color.rgb(52,55,59)); c.drawPath(road,p)
        for (i in 1..3) {
            val topX=w*(.36f+i*.07f); val bottomX=w*(.09f+i*.205f)
            for (j in 0..8) {
                val t=((j/8f+(distance*.018f)%0.12f)%1f); val y=h*(.28f+t*.72f); val x=topX+(bottomX-topX)*t
                paint(if(i==2) Color.rgb(235,190,55) else Color.WHITE)
                val dash=h*(.008f+t*.025f); c.drawRect(x-dash*.12f,y,x+dash*.12f,y+dash*1.7f,p)
            }
        }
        if (!menu && !crashed) {
            distance += speed*dt*.015f; spawnClock += dt
            if (spawnClock>.8f) { spawnClock=0f; traffic.add(TrafficCar(rnd.nextInt(if(twoWay)4 else 2),0f,trafficColors.random(rnd))) }
            val it=traffic.iterator()
            while(it.hasNext()) {
                val car=it.next(); car.progress += dt*(.12f+speed/850f)
                if(car.progress>1.15f) it.remove() else {
                    drawCar(c,laneX(w,car.lane,car.progress),h*(.28f+car.progress*.72f),w*(.018f+car.progress*.035f),car.color,false)
                    if(car.progress>.82f && car.progress<.99f && car.lane==playerLane) crashed=true
                }
            }
        } else {
            traffic.forEach { drawCar(c,laneX(w,it.lane,it.progress),h*(.28f+it.progress*.72f),w*(.018f+it.progress*.035f),it.color,false) }
        }
        if (!menu) {
            playerLane=playerLane.coerceIn(0,if(twoWay)3 else 1)
            drawCar(c,laneX(w,playerLane,.91f),h*.86f,w*.07f,carColors[selectedCar],true)
            paint(Color.argb(150,0,0,0)); c.drawRoundRect(w*.02f,h*.03f,w*.32f,h*.18f,14f,14f,p)
            label(c,"$speed KM/H",w*.04f,h*.085f,h*.045f)
            label(c,"DISTANCE  ${distance.toInt()} m",w*.04f,h*.145f,h*.032f)
            button(c,w*.04f,h*.73f,w*.17f,h*.94f,"◀")
            button(c,w*.83f,h*.73f,w*.96f,h*.94f,"▶")
            button(c,w*.38f,h*.82f,w*.48f,h*.96f,"−")
            button(c,w*.52f,h*.82f,w*.62f,h*.96f,"+")
            label(c,if(twoWay)"TWO WAY" else "ONE WAY",w*.96f,h*.08f,h*.035f,Color.WHITE,true)
        }
        if(menu) drawMenu(c,w,h) else if(crashed) drawCrash(c,w,h)
        postInvalidateOnAnimation()
    }

    private fun laneX(w:Float,lane:Int,t:Float):Float {
        val top=w*(.36f+(lane+.5f)*.07f); val bottom=w*(.09f+(lane+.5f)*.205f)
        return top+(bottom-top)*t
    }
    private fun drawCar(c:Canvas,x:Float,y:Float,size:Float,col:Int,player:Boolean) {
        val cw=size*1.25f; val ch=size*1.9f
        paint(Color.argb(90,0,0,0)); c.drawOval(x-cw*.65f,y+ch*.32f,x+cw*.65f,y+ch*.48f,p)
        paint(Color.rgb(20,22,25)); c.drawRoundRect(x-cw*.55f,y-ch*.45f,x+cw*.55f,y+ch*.45f,cw*.16f,cw*.16f,p)
        paint(col); c.drawRoundRect(x-cw*.48f,y-ch*.5f,x+cw*.48f,y+ch*.42f,cw*.18f,cw*.18f,p)
        paint(Color.rgb(40,70,85)); c.drawRoundRect(x-cw*.34f,y-ch*.28f,x+cw*.34f,y+ch*.08f,cw*.12f,cw*.12f,p)
        paint(Color.rgb(255,245,205)); c.drawRect(x-cw*.39f,y+ch*.25f,x-cw*.17f,y+ch*.36f,p); c.drawRect(x+cw*.17f,y+ch*.25f,x+cw*.39f,y+ch*.36f,p)
        if(player) { paint(Color.WHITE); c.drawRect(x-cw*.025f,y-ch*.45f,x+cw*.025f,y+ch*.25f,p) }
    }
    private fun button(c:Canvas,l:Float,t:Float,r:Float,b:Float,s:String) {
        paint(Color.argb(175,10,15,22)); c.drawRoundRect(l,height*t,r,height*b,18f,18f,p)
        label(c,s,(l+r)/2f,height*(t+b)/2f+height*.025f,height*.06f,Color.WHITE,true)
    }
    private fun drawMenu(c:Canvas,w:Float,h:Float) {
        paint(Color.argb(205,5,12,20)); c.drawRect(0f,0f,w,h,p)
        label(c,"OLD RACING",w/2,h*.22f,h*.13f,Color.rgb(255,190,40),true)
        label(c,"CHOOSE YOUR CAR",w/2,h*.34f,h*.045f,Color.WHITE,true)
        for(i in 0..2) {
            val x=w*(.27f+i*.23f); drawCar(c,x,h*.51f,w*.06f,carColors[i],true)
            label(c,carNames[i],x,h*.64f,h*.03f,if(i==selectedCar)Color.YELLOW else Color.WHITE,true)
        }
        button(c,w*.31f,h*.71f,w*.49f,h*.84f,"START")
        button(c,w*.52f,h*.71f,w*.70f,h*.84f,if(twoWay)"TWO WAY" else "ONE WAY")
        label(c,"Touch left/right to steer • + / − changes speed",w/2,h*.94f,h*.027f,Color.LTGRAY,true)
    }
    private fun drawCrash(c:Canvas,w:Float,h:Float) {
        paint(Color.argb(205,0,0,0)); c.drawRect(w*.25f,h*.25f,w*.75f,h*.75f,p)
        label(c,"CRASH!",w/2,h*.43f,h*.1f,Color.RED,true)
        label(c,"Distance: ${distance.toInt()} m",w/2,h*.53f,h*.045f,Color.WHITE,true)
        button(c,w*.39f,h*.60f,w*.61f,h*.71f,"RESTART")
    }
    override fun onTouchEvent(e:MotionEvent):Boolean {
        val w=width.toFloat(); val h=height.toFloat()
        if(e.action==MotionEvent.ACTION_DOWN) {
            if(menu) {
                if(e.y>h*.39f && e.y<h*.68f) selectedCar=when { e.x<w*.38f->0; e.x<w*.62f->1; else->2 }
                else if(e.y>h*.68f) {
                    if(e.x>w*.50f) twoWay=!twoWay else {
                        menu=false; crashed=false; distance=0f; speed=105; playerLane=if(twoWay)1 else 0; traffic.clear()
                        repeat(4){traffic.add(TrafficCar(rnd.nextInt(if(twoWay)4 else 2),rnd.nextFloat()*.75f,trafficColors.random(rnd)))}
                    }
                }
            } else if(crashed) { menu=true }
            else if(e.x<w*.25f) playerLane=max(0,playerLane-1)
            else if(e.x>w*.75f) playerLane=min(if(twoWay)3 else 1,playerLane+1)
            else if(e.y>h*.78f) speed=if(e.x<w*.5f)max(50,speed-10) else min(260,speed+10)
            invalidate()
        }
        return true
    }
}
