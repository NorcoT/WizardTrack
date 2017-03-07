import processing.serial.*;
import guru.ttslib.*; // Text to speech

// DEFIN GLOBAL VARIABLES
Serial myPort;       // declare serial port object
PrintWriter output;  // Declare txt output object
TTS tts; // Text to Speech Object

float xPos = 1;         // initial horizontal position
float yPos = 0; float yPos2 = 0;       // initial vertical position
float rssiARaw; float rssiA; float rssiAlpf = 0;
float graphA; float graphAlpf; float barA; float barAlpf;
float maxRssi;
float channel;
float time;

float threshold = 190; // SETTING FOR RSSI LPF THRESHOLD FOR LAP
float minLapTime = 5; // MIN LAP TIME THRESHOLD IN SECONDS
float graphThreshold;
int thresholdLineColour;

// CALIBRATION VALUES FOR RAW RSSI VALUES - THESE ARE USED TO MAP THE GRAPH
float calibMinRssiA = 70; 
float calibMaxRssiA = 200;

// LAYOUT SETTINGS
int graphHeight = 400;

// COUNTERS
int lap = 0;
int j;
float lapStart;
float lapFinish;
float lapTime;

// ARRAYS
float[] lapTimeArray = new float[100];
float[] graphAArray = new float[800];
float[] graphAlpfArray = new float[800];

void setup () {
  size(800, 600);    // Size of Window
  background(0);  // set inital background:

  println(Serial.list());  // Print serial list to aid configuration
  
  output = createWriter("DataOutput.txt"); // setuput print file

  // Setup serial connection
  myPort = new Serial(this, Serial.list()[0], 112500);
  myPort.bufferUntil('\n');
  
  // Setup text to speech
  tts = new TTS();
   //<>//
}


void draw () {
  // CLEAR BACKGROUND
  background(0);
 
  // DRAW THRESHOLD LINE
  graphThreshold = height - map(threshold, calibMinRssiA, calibMaxRssiA, 0, graphHeight);
  thresholdLineColour = round(map(graphAlpf,graphHeight*0.75,graphHeight,1,255)); //GRADE LINE COLOUR BASED ON RSSI LPF
  stroke(thresholdLineColour,0,0);
  strokeWeight(3);
  line(0,graphThreshold,width,graphThreshold);  
  
  // LOOP ARRAY TO DRAW GRAPH A
  strokeWeight(1);
  for(int i=0;i<graphAArray.length-2;i++){
      stroke(127, 34, 255);  // Line properties
      line(i, height - graphAArray[i], i, height - graphAArray[i+1]);  // Plot Line
      stroke(255);  // Line properties
      line(i, height - graphAlpfArray[i], i, height - graphAlpfArray[i+1]);  // Plot Line
  } //<>//
 
  //DRAW RSSI BAR
  fill(128);
  noStroke();
  rect(10,60,barA,8);
  
  //DRAW RSSI LPF BAR
  fill(80);
  noStroke();
  rect(10,68,barAlpf,8);  
 
  //DISPLAY TEXT
  //ROW 1
  fill(255);
  textSize(12);
  text("Channel: " +str(channel),10,30);
  text("Max RSSI: " +nf(maxRssi,1,2),210,30);
  
  //ROW 2
  fill(255);
  textSize(12);
  text("RSSI A: " +nf(rssiARaw,1,2),10,50);
  text("RSSI A LPF: " +nf(rssiAlpf,1,2),210,50);

  
  //DISPLAY TIMER
  fill(255);
  textSize(20);
  text("Lap: " +str(lap),10,150);   // Display Lap
  text("Elapsed (s): " +str((millis()-lapStart)/1000),210,150);   // Display lap elapsed time
  if(lap>1){
    text("Last Lap (s): " +str((lapTimeArray[lap-1])/1000),510,150);   // Display last lap time
  }
  
  
  //DISPLAY LAP INFO
  if(lap > 0){
    fill(255);
    textSize(15);
    
    if(lap<6){
      j=lap;
    } else {
      j=6;
    }
    for(int i=0;i<j;i++){
        int resultLapNumber = lap - i;
        String resultLapTime = nf(lapTimeArray[resultLapNumber]/1000,1,2);
        text("Lap " +resultLapNumber+ ": " +resultLapTime,10,200+(20*i));
    }
  }
  
}


void serialEvent (Serial myPort) {
  // get the ASCII string:
  String inString = myPort.readStringUntil('\n');

  if (inString != null) {
 
    // Process the string recieved
    inString = trim(inString); // Trim whitespace
    String inArray[] = splitTokens(inString); // Store string from RX5808 floato array
    channel = float(inArray[0]);
    rssiA = float(inArray[1]);
    rssiARaw = float(inArray[2]);
    time = millis();
    
    // Check RSSI
    checkMaxRssi(rssiARaw);
    
    // Filter RSSI in LPF
    rssiAlpf = LPF(rssiAlpf,rssiARaw,0.1);

/*
    println(channel+"\t"+rssiA+"\t"+rssiARaw+"\t"+rssiB+"\t"+rssiBRaw+"\t"+time);
    output.println(channel+"\t"+rssiA+"\t"+rssiARaw+"\t"+rssiB+"\t"+rssiBRaw+"\t"+time);
*/

    // convert to float and map to the screen height: 
    graphA = map(rssiARaw, calibMinRssiA, calibMaxRssiA, 0, graphHeight);
    barA = map(rssiARaw, calibMinRssiA, calibMaxRssiA, 0, (width-20/2));
    graphAlpf = map(rssiAlpf, calibMinRssiA, calibMaxRssiA, 0, graphHeight);
    barAlpf = map(rssiAlpf, calibMinRssiA, calibMaxRssiA, 0, (width-20/2));

    // store graph values into scrolling graph arrays
    arrayCopy(graphAArray,1,graphAArray,0,graphAArray.length-1);  // Shift Array to the left
    graphAArray[graphAArray.length-1] = graphA;
    
    arrayCopy(graphAlpfArray,1,graphAlpfArray,0,graphAlpfArray.length-1);  // Shift Array to the left
    graphAlpfArray[graphAlpfArray.length-1] = graphAlpf;
    
    // LAP TIMING
    // Detect RSSI greater than threshold
    if(rssiAlpf > threshold){
      if(lap<1){
        // First lap, just set the start time
        lapStart = time;
        lap++;
      } else {
        // Not first lap, start time exists
        // Check minLapTimeThreshold
        if((time-lapStart)>(minLapTime*1000)){
          lapFinish = time; //<>//
          lapTime = lapFinish - lapStart; // calculate lap time
          lapStart = lapFinish; // Set start time for next lap
          lapTimeArray[lap] = lapTime; // Store Lap Time into Array
          tts.speak("Lap " +str(lap)+ "." +str((lapTimeArray[lap])/1000)+ " seconds."); // Speak lap time data
          lap++;
        }
      }
    }
    
    
    
  }
}

// Function to check if rssi is max, save if so
void checkMaxRssi(float rssi){
  if(rssi > maxRssi){
    // Current rssi is larger than the stored
    maxRssi = rssi;
  }
}  

// Function to LPF the RSSI values
// filtered value = Previous Filtered RSSI - ( LPF_Factor * (Previous Filtered RSSI - New RSSI)
float LPF(float rssiOld, float rssiNew, float beta){
  rssiNew = rssiOld-(beta*(rssiOld-rssiNew));
  return rssiNew;
}