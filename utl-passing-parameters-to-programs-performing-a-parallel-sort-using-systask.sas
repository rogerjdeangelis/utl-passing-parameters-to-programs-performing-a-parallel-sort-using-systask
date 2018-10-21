Passing parameters to programs performing a parallel sort using systask

This algortith provides a more natural way to pass parameters to parallel SAS batch tasks?

github
https://tinyurl.com/y8ahh98m
https://github.com/rogerjdeangelis/utl-passing-parameters-to-programs-performing-a-parallel-sort-using-systask

see StackOverflow SAS
https://tinyurl.com/ydbgd5t4
https://stackoverflow.com/questions/52884354/how-to-properly-quote-parameters-when-passing-them-to-another-sas-program-when-c

other repositories
https://github.com/rogerjdeangelis/utl_scoring_100_million_in_9_seconds
https://github.com/rogerjdeangelis/utl-partitioning-your-table-for-a-big-sort
https://github.com/rogerjdeangelis/utl_parallell_processing_creating_8_subsets

You do not know the number of observations because the input is a view.
You also do not know how skewed variable 'RGN' is, so you cannot use rgn  and observation ranges.
However you do know the assigned 'KEY' variable tends to be uniformly distributed.

PROBLEM: Parallelize this sort

proc sort data=sd1.bigdata(where=(rgn=1)) out=sorted noequals;
  by ran;
run;quit;


INPUT (key is a integer)
=========================

SD1.BIGDATA total obs=1,600

    KEY        RAN      RGN

  1178389    0.75040     1
  1221114    0.90603     1
  1124665    0.78644     1
  1436074    0.18769     2
  1713934    0.96750     1
  1861344    0.55486     2
  1653095    0.14208     2
  1328750    0.76996     2
  1046466    0.52208     2


EXAMPLE OUTPUT
--------------                 | RULES
 WORK.WANT total obs=780       |
                               |
    KEY         RAN      RGN   | SORT BY RAN WHERE RGN=1
                               |
  1640705    0.000012     1    |
  1841700    0.002042     1    |
  1849843    0.002345     1    |
  1131632    0.002993     1    |
  1478434    0.003434     1    |
  1806003    0.005872     1    |


SINGLE SORT SOLUTION
--------------------

 proc sort data=sd1.bigdata(where=(rgn=1)) out=sorted noequals;
   by ran;
 run;quit;

MULLTIPE SEQUENTIAL INTERACTIVE SORTS - WE WANT TO PARALLELIZE THIS
-------------------------------------------------------------------

 proc sort data = sd1.bigdata(where=(mod(key,8)=1 and rgn=1)) out= sd1.a1 noequals;by ran;run;quit;
 proc sort data = sd1.bigdata(where=(mod(key,8)=2 and rgn=1)) out= sd1.a2 noequals;by ran;run;quit;
 proc sort data = sd1.bigdata(where=(mod(key,8)=3 and rgn=1)) out= sd1.a3 noequals;by ran;run;quit;
 proc sort data = sd1.bigdata(where=(mod(key,8)=4 and rgn=1)) out= sd1.a4 noequals;by ran;run;quit;
 proc sort data = sd1.bigdata(where=(mod(key,8)=5 and rgn=1)) out= sd1.a5 noequals;by ran;run;quit;
 proc sort data = sd1.bigdata(where=(mod(key,8)=6 and rgn=1)) out= sd1.a6 noequals;by ran;run;quit;
 proc sort data = sd1.bigdata(where=(mod(key,8)=7 and rgn=1)) out= sd1.a7 noequals;by ran;run;quit;
 proc sort data = sd1.bigdata(where=(mod(key,8)=0 and rgn=1)) out= sd1.a0 noequals;by ran;run;quit;

 data want_vue/view=want_vue; * do not create a physical view - can be slower - depends on I/O channels?;
   set
      sd1.a1
      sd1.a2
      sd1.a3
      sd1.a4
      sd1.a5
      sd1.a6
      sd1.a7
      sd1.a0;
 by ran;
 run;quit;


PROCESS
=======

 1.  These are mutually exclusive partitions

     sd1.bigdata(where=(mod(key,8)=0))
     sd1.bigdata(where=(mod(key,8)=1))
     ...
     sd1.bigdata(where=(mod(key,8)=7))

 2. Put the sas command with the static options in a macro variable

    %let _s=%sysfunc(compbl(C:\Progra~1\SASHome\SASFoundation\9.4\sas.exe -sysin
    c:\nul -sasautos c:\oto -autoexec c:\oto\Tut_Oto.sas
    -work d:\wrk));

 3. Wrap the programs you want to execute in a macro

    %macro cutTbl(remainder,rgn);
      libname sd1 "d:/sd1";
      proc sort data = sd1.bigdata(where=(mod(key,8)=&remainder and rgn=&rgn)) out= sd1.a&remainder noequals;
      by ran;
      run;quit;
    %mend cutTbl;

 4. Put the macro in your autocall library

 5. Put you SAS invocation with static options in a macro variable
    Note sysin is null

    %let _s=%sysfunc(compbl(C:\Progra~1\SASHome\SASFoundation\9.4\sas.exe -sysin
         c:\nul -sasautos c:\oto -autoexec c:\oto\Tut_Oto.sas
         -work d:\wrk));

 6. Execute 8 systasks

    options noxwait noxsync;
    %let tym=%sysfunc(time());
    systask kill sys1 sys2 sys3 sys4  sys5 sys6 sys7 sys8;
    systask command "&_s -termstmt %nrstr(%cutTbl(1,1);) -log d:\log\a1.log" taskname=sys1;
    systask command "&_s -termstmt %nrstr(%cutTbl(2,1);) -log d:\log\a2.log" taskname=sys2;
    systask command "&_s -termstmt %nrstr(%cutTbl(3,1);) -log d:\log\a3.log" taskname=sys3;
    systask command "&_s -termstmt %nrstr(%cutTbl(4,1);) -log d:\log\a4.log" taskname=sys4;
    systask command "&_s -termstmt %nrstr(%cutTbl(5,1);) -log d:\log\a5.log" taskname=sys5;
    systask command "&_s -termstmt %nrstr(%cutTbl(6,1);) -log d:\log\a6.log" taskname=sys6;
    systask command "&_s -termstmt %nrstr(%cutTbl(7,1);) -log d:\log\a7.log" taskname=sys7;
    systask command "&_s -termstmt %nrstr(%cutTbl(0,1);) -log d:\log\a8.log" taskname=sys8;
    waitfor sys1 sys2 sys3 sys4  sys5 sys6 sys7 sys8;
    %put %sysevalf( %sysfunc(time()) - &tym);?

    data want/view=want;
      set
         sd1.a1
         sd1.a2
         sd1.a3
         sd1.a4
         sd1.a5
         sd1.a6
         sd1.a7
         sd1.a0;
    by ran;
    run;quit;

  7. d:\log\a1.log  (there are 8 logs)

     NOTE: Libref SD1 was successfully assigned as follows:
           Engine:        V9
           Physical Name: d:\sd1

     NOTE: There were 115 observations read from the data set SD1.BIGDATA.

           WHERE (MOD(key, 8)=1) and (rgn=1);

     NOTE: The data set SD1.A1 has 115 observations and 3 variables.

     NOTE: PROCEDURE SORT used (Total process time):
           real time           0.08 seconds
           cpu time            0.03 seconds

OUTPUT
======
 see above

*                _               _       _
 _ __ ___   __ _| | _____     __| | __ _| |_ __ _
| '_ ` _ \ / _` | |/ / _ \   / _` |/ _` | __/ _` |
| | | | | | (_| |   <  __/  | (_| | (_| | || (_| |
|_| |_| |_|\__,_|_|\_\___|   \__,_|\__,_|\__\__,_|

;

* create some data;
libname sd1 "d:/sd1";
data sd1.bigdata;
 retain key;
 do rec=1 to 1600;
   ran=uniform(0123);
   rgn=1+int(2*uniform(2356));
   key=1e6+int(1e6*uniform(1234));
   output;
 end;
 drop rec;
run;quit;

* SAVE the program in autocall library c:/oto;
data _null_;file "c:\oto\cutTbl.sas" lrecl=512;input;put _infile_;putlog _infile_;
cards4;
%macro cutTbl(remainder,rgn);
  libname sd1 "d:/sd1";
  proc sort data = sd1.bigdata(where=(mod(key,8)=&remainder and rgn=&rgn)) out= sd1.a&remainder noequals;
  by ran;
  run;quit;
%mend cutTbl;
;;;;
run;quit;



