#!/bin/ksh
#####################################################################
echo "------------------------------------------------"
echo "This job ..."
echo "------------------------------------------------"
echo "History:  AUG 1997 - First implementation of this new script."
#####################################################################
# Robert Grumbine 1 March 1995 et seq.
#
# 30 March 2012   - Add SSMI-S processing, convert to vertical structure
# 30 March 2012   - Direct production of grib2 files
#
# 16 August 2017  - Add ASMR2
########################################################################

set -x

### Definition of the Fix fields:
export FNLAND=${FNLAND:-${FIXseaice_analysis}/seaice_nland.map}
export FNLAND127=${FNLAND127:-${FIXseaice_analysis}/seaice_nland127.map}
export FSLAND=${FSLAND:-${FIXseaice_analysis}/seaice_sland.map}
export FSLAND127=${FSLAND127:-${FIXseaice_analysis}/seaice_sland127.map}
export FGLAND5MIN=${FGLAND5MIN:-${FIXseaice_analysis}/seaice_gland5min}
export FPOSTERIORI5=${FPOSTERIORI5:-${FIXseaice_analysis}/seaice_posteriori_5min}
export FPOSTERIORI30=${FPOSTERIORI30:-${FIXseaice_analysis}/seaice_posteriori_30min}
export FDIST=${FDIST:-${FIXseaice_analysis}/seaice_alldist.bin}
export FGSHHS=${FGSHHS:-${FIXseaice_analysis}/seaice_lake_isleout}

cd $DATA

##############################
#
# START FLOW OF CONTROL
#
# 1) Get the Date from /com/date
#    -- Now done in J-job, not here.
# 2) Run the dumpscript to retrieve a day's data
# 3) Process the bufr output into something readable
# 4) Run the analysis on the files
# -- 2,3,4 are repeated for each satellite being used
# 5) Copy the base analyst's (L3) grids to the running location
#
##############################


########################################
msg="HAS BEGUN!"
postmsg "$jlogfile" "$msg"
########################################

mailbody=mailbody.txt
rm -f $mailbody

#----------------------------------------------------------

#----------------------------------------------------------
#Begin ordinary processing.
#---------------------------------------------------------
#Dummy variables at this point, formerly used and may be useful
# again in the future.  Robert Grumbine 6 August 1997.
jday=1
refyear=2012

#BUFR------------------------------------------------------
#Run the dumpscript to retrieve a day's data
#----------------------------------------------------------
if [ -z $obsproc_dump_ver ] ; then
  echo null obsproc_dump_ver
  export obsproc_dump_ver=v4.0.0
  export obsproc_shared_bufr_dumplist_ver=v1.4.0
fi

set -e

export pgm=dumpjb2
. prep_step
${DUMPJB} ${PDY}00 12 ssmisu
export err=$?
if [ $err -ne 0 ] ; then
  msg="WARNING:  Continuing without ssmiu data"
  postmsg "$jlogfile" "$msg"
  echo "********************************************************************" >> $mailbody
  echo "*** WARNING:  dumpjb returned status $err.  Continue without ssmisu." >> $mailbody
  echo "********************************************************************" >> $mailbody
fi
touch ssmisu.ibm # ensures that file exists in rare event that dump is empty


# send email if any dumpjb calls returned non-zero status
  if [ -s "$mailbody" ] ; then
     subject="$job degraded due to missing data"
     mail.py -s "$subject" < $mailbody
  fi

#--------------------------------------------------------------------
#Process the bufr output into something readable: bufr --> l1b
#--------------------------------------------------------------------
##################Decode SSMI data
# The last SSMI instrument died 9 August 2021. These lines kept here as comments 
#   for when historical re-runs are done before that date.  Robert Grumbine
#export pgm=seaice_ssmibufr
#. prep_step
#
#ln -sf ssmit.ibm fort.14
#touch bufrout
#
#startmsg
#$EXECseaice_analysis/seaice_ssmibufr >> $pgmout 2> errfile
#export err=$?
#if [ $err -ne 0 ] ; then
#  msg="WARNING:  Continuing without ssmibufr"
#  postmsg "$jlogfile" "$msg"
#  echo "********************************************************************" >> $mailbody
#  echo "*** WARNING:  ssmibufr returned status $err.  Continue without ssmi " >> $mailbody
#  echo "********************************************************************" >> $mailbody
#fi
#
#echo bufrout > delta
#mv fort.51 bufrout

##################Decode SSMI-S data
export pgm=ssmisu_tol2
. prep_step

export XLFRTEOPTS="unit_vars=yes"
ln -sf ssmisu.ibm fort.11

startmsg
$EXECseaice_analysis/ssmisu_tol2 >> $pgmout 2> errfile
mv fort.51 ssmisu.bufr
export err=$?
if [ $err -ne 0 ] ; then
  msg="WARNING:  Continuing without ssmisu"
  postmsg "$jlogfile" "$msg"
  echo "********************************************************************" >> $mailbody
  echo "*** WARNING:  ssmisubufr returned status $err.  Continue without ssmisu " >> $mailbody
  echo "********************************************************************" >> $mailbody
  exit 1
fi

#---------------------------------------------------------------------
# Translate from l1b to l2 in ssmi, ssmis
# AMSR2 remains straight shot l1b to l3
# Robert Grumbine 9 April 2021
#---------------------------------------------------------------------

#---------------------------------------------------------------------
#----------------------------------------------------------
# Run the analysis on the SSMI-S datafiles
# Input files =  delta, $FIXseaice_analysis/seaice_nland127.map, $FIXseaice_analysis/seaice_sland127.map
# Output files = n3ssmi.$PDY, s3ssmi.$PDY, ssmisnorth.$PDY, ssmissouth.$PDY
# Arguments (currently not used) - $jday : Julian Day,
#                                  $refyear : 4 digit year
#           (used)                 285      : satellite number (285 = F17)
# 249 = F16, 286 = F18
#----------------------------------------------------------

#Process SSMI-S data to analyst (L3) grids
export pgm=ssmi_tol2
. prep_step

cp $FIXseaice_analysis/seaice_TBthark.tab.ssmisu .
cp $FIXseaice_analysis/seaice_TBowark.tab.ssmisu .
cp $FIXseaice_analysis/seaice_TBowant.tab.ssmisu .
cp $FIXseaice_analysis/seaice_TBfyark.tab.ssmisu .
cp $FIXseaice_analysis/seaice_TBfyant.tab.ssmisu .
cp $FIXseaice_analysis/seaice_TBccark.tab.ssmisu .
cp $FIXseaice_analysis/seaice_TBccant.tab.ssmisu .
echo ssmisu.bufr > delta


startmsg
ln -sf ssmisu.ibm fort.11
$EXECseaice_analysis/ssmisu_tol2 
#produces l2out.f285.51.nc, l2out.f286.52.nc
export err=$?;err_chk

exit

export pgm=ssmi_tol3
. prep_step
startmsg
$EXECseaice_analysis/ssmisu_tol3 l2out.f285.51.nc nmap.${PDY}.f17 smap.${PDY}.f17
$EXECseaice_analysis/ssmisu_tol3 l2out.f286.52.nc nmap.${PDY}.f18 smap.${PDY}.f18
export err=$?;err_chk


#----------------------------------------------------------

#-----------------------------------------------------------
#Copy the base l2 and l3 ssmis grids to the running location
#-----------------------------------------------------------
if [ $SENDCOM = "YES" ]
then
#L2 ice files
  cp l2out.* ${COMOUT}
#L3 ice files
  cp nmap.${PDY}.f1[578] ${COMOUT}
  cp smap.${PDY}.f1[578] ${COMOUT}

fi


echo completed the L2 and L3 analyses for SSMI-S
#-----------------------------------------------------------

if [ $qc = "true" ]
then
  msg="HAS COMPLETED NORMALLY!"
  echo $msg
  postmsg "$jlogfile" "$msg"

   #####################################################################
   # GOOD RUN
   set +x
   echo "**************JOB $job COMPLETED NORMALLY ON THE IBM SP"
   echo "**************JOB $job COMPLETED NORMALLY ON THE IBM SP"
   echo "**************JOB $job COMPLETED NORMALLY ON THE IBM SP"
   set -x
   #####################################################################
else
   #####################################################################
   # FAILED
   set +x
   echo "**************ABNORMAL TERMIMATION JOB $job ON THE IBM SP"
   echo "**************ABNORMAL TERMIMATION JOB $job ON THE IBM SP"
   echo "**************ABNORMAL TERMIMATION JOB $job ON THE IBM SP"
   set -x
   #####################################################################
fi

############## END OF SCRIPT #######################
