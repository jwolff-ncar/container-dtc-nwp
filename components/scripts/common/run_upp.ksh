#!/bin/ksh
#
set -x
#--------------------------------------------------------
# Updates:
#
# August 2005: Hui-Ya Chuang, NCEP: This script uses 
# NCEP's Unipost to post processes WRF native model 
# output, and uses copygb to horizontally interpolate posted 
# output from native A-E to a regular projection grid. 
#
# July 2006: Meral Demirtas, NCAR/DTC: Added new "copygb" 
# options and revised some parts for clarity. 
#
# April 2015: Modified to run NMM-B/NEMS, KRF(DTC)
#--------------------------------------------------------
# This script performs 2 jobs:
#
# 1. Run Unipost
# 2. Run copygb to horizontally interpolate output from 
#    native A-E to a regular projection grid
#--------------------------------------------------------

# Include case-specific settings
. /home/scripts/case/set_env.ksh

#----------------------------------------------------------------------------------
#--- USER EDIT DESCIPTIONS --------------------------------------------------------
# See UPP User's Guide for more information
# http://www.dtcenter.org/upp/users/docs/user_guide/V3/upp_users_guide.pdf 
#----------------------------------------------------------------------------------
# TOP_DIR       : Top level directory for source codes (UPPV3.0 and WRFV3)
# DOMAINPATH    : Working directory for this run.
# UNIPOST_HOME  : Where the UPP build directory located
# POSTEXEC      : Where the UPP executables are located
# SCRIPTS       : Where the UPP scripts directory is (i.e. UPPV3.0/scripts/)
# modelDataPath : Where are the model data files to be processed located
#               : e.g. "wrfprd/" for WRF-based runs; "nemsprd/" for NMMB forecasts.
# paramFile     : Name and location of cntrl.parm file (wrf_cntrl.parm or nmb_cntrl.parm)
#                 Text file lists desired fields for grib1 output. Template in UPPV3.0/parm/
# xmlCntrlFile  : Name and location of postcntrl.xml. (Copy template to be named postcntrl.xml) 
#                 XML file lists desired fields for grib2 output. 
#                 Template in UPPV3.0/parm/wrfcntrl.xml or  UPPV3.0/parm/nmbcntrl.xml
# txtCntrlFile  : Name and location of postxconfig-NT.txt for grib2
#                 Text file listing desired fields to be generated by the user before running UPP.
#                 Step 1: Edit postcntrl.xml to include desired fields (template in UPPV3.0/parm)
#                 Step 2: Validate postcntrl.xml and post_avblflds.xml
#                 Step 3: Type 'make' in parm directory to generate the post flat file
# dyncore       : What model is used 
# inFormat      : Format of the model data 
#                 arw - "netcdf" or "binary" or "binarympiio"
#                 nmm - "netcdf" or "binary" or "binarympiio" 
#                 nmb - "binarynemsio"
# outFormat     : Format of output from UPP 
#                 grib
#                 grib2 - NOTE: grib2 not extensively tested, use with caution. 
#                         No grib2 destaggering support for NMB or NMM grids;
#                         Suggested use with ARW only at this time.  
# startdate     : Forecast start date
# fhr           : First forecast hour to be post-processed
# lastfhr       : Last forecast hour to be post-processed
# incrementhr   : Increment (in hours) between forecast files
#                 * Do not set to 0 or the script will loop continuously *
# domain_list   : List of domains for run
# RUN_COMMAND   : System run command for serial or parallel runs, examples below.
# copygb_opt    : Copygb grid specfication option to destagger and regrid NMM or NMB
#                 "lambert" = Grid spec for copygb generated internally for lambert data
#                 "lat-lon" = Grid spec for copygb generated internally for lat-lon data
#                 "awips"   = Use a predefined awips grid, e.g. 212
#                             ** Uncomment "export awips_id= " and add desired grid number.
#                 "custom"  = Specify your own grid  
#                             ** Uncomment "export custom_gds= " and add grid description.
#
#----------------------------------------------------------------------------------
#--- BEGIN USER EDIT HERE ---------------------------------------------------------
#----------------------------------------------------------------------------------

# Set relevant paths and data information
# This script assumes you created a directory $DOMAINPATH/postprd
# and that your model output is in $DOMAINPATH/wrfprd or $DOMAINPATH/nemsprd
# as recommended in the users guide where UPP will output.
export TOP_DIR=/home/
export DOMAINPATH=${TOP_DIR}
export UNIPOST_HOME=/comsoftware/upp/UPPV4.0.1
export POSTEXEC=${UNIPOST_HOME}/bin
export SCRIPTS=${UNIPOST_HOME}/scripts
export modelDataPath=/home/wrfprd            # or nemsprd
export paramFile=/home/scripts/case/wrf_cntrl.parm   # or nmb_cntrl.parm
export xmlCntrlFile=/home/scripts/case/postcntrl.xml # for grib2
export txtCntrlFile=/home/scripts/case/postxconfig-NT_WRF.txt # grib2

# Specify Dyn Core (ARW or NMM or NMB in upper case)
export dyncore="ARW"

# Set run command: 

# Serial command example
export RUN_COMMAND="${POSTEXEC}/unipost.exe "

# Parallel command examples:
#export RUN_COMMAND="mpirun -np 1 ${POSTEXEC}/unipost.exe "
#export RUN_COMMAND="mpirun.lsf ${POSTEXEC}/unipost.exe "

# DEBUG command example found further below, search "DEBUG" 

# If NMM or NMB, specify COPYGB grid spec option
export copygb_opt="lambert"

# If using awips grid, uncomment awips_id and modify to desired grid
# If familiar with copygb and selecting custom, uncomment custom_gds
# and modify to fit your needs. Use at own risk!
#export awips_id="212" 
#export custom_gds="255 3 109 91 37748 -77613 8 -71000 10379 9900 0 64 42000 42000"

# Shouldn't need to edit these.
# tmmark is an variable used as the file extention of the output
# filename .GrbF is used if this variable is not set
# COMSP is a variable used as the initial string of the output filename
export tmmark=tm00
export MP_SHARED_MEMORY=yes
export MP_LABELIO=yes

#----------------------------------------------------------------------
#--- END USER EDIT ----------------------------------------------------
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# Shouldn't need to edit below unless something goes wrong or debugging
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# Do some checks for directory/executable existence, user input, etc.
#----------------------------------------------------------------------
if [ ! -d ${POSTEXEC} ]; then
  echo "ERROR: POSTEXEC, '${POSTEXEC}', does not exist"
  exit 1
fi

if [ ! -x ${POSTEXEC}/unipost.exe ]; then
  echo "ERROR: unipost.exe, '${POSTEXEC}/unipost.exe', does not exist or is not executable."
  exit 1
fi
if [ ! -x ${POSTEXEC}/copygb.exe ]; then
  echo "ERROR: copygb.exe, '${POSTEXEC}/copygb.exe', does not exist or is not executable."
  exit 1
fi
if [ ! -x ${POSTEXEC}/ndate.exe ]; then
  echo "ERROR: ndate.exe, '${POSTEXEC}/ndate.exe', does not exist or is not executable."
  exit 1
fi

# Set tag based on user defined $dyncore (ARW or NMM or NMB in upper case)
if [ $dyncore = "ARW" ]; then
   export tag=NCAR
elif [ $dyncore = "NMM" ]; then
   export tag=NMM
elif [ $dyncore = "NMB" ]; then
   export tag=NMM
else
    echo "${dyncore} is not supported. Edit script to choose ARW or NMM or NMB dyncore."
    exit
fi

if [[ ${dyncore} == "ARW" || ${dyncore} == "NMM" ]]; then
   if [[ ${inFormat} != "netcdf" && ${inFormat} != "binary" && ${inFormat} != "binarympiio" ]]; then
      echo "ERROR: 'inFormat' must be 'netcdf' or 'binary' or 'binarympiio' for ARW or NMM model output. Exiting... "
      exit 1
   fi 
elif [ ${dyncore} == "NMB" ]; then
   if [[ ${inFormat} != "binarynemsio" ]]; then
      echo "ERROR: 'inFormat' must be 'binarynemsio' for NMB model output. Exiting... "
      exit 1
   fi
fi

if [[ ${outFormat} == "grib" ]]; then
   if [ ! -e ${paramFile} ]; then
      echo "ERROR: 'paramFile' not found in '${paramFile}'.  Exiting... "
      exit 1
   fi
elif [[ ${outFormat} == "grib2" ]]; then
   if [ ! -e ${xmlCntrlFile} ]; then
      echo "ERROR: 'xmlCntrlFile' not found in '${xmlCntrlFile}'.  Exiting... "
      exit 1
   fi
fi
 
if [ ! -d ${DOMAINPATH}/postprd ]; then
  echo "ERROR: DOMAINPATH/postprd, '${DOMAINPATH}/postprd', does not exist. Exiting..."
  exit 1
fi

if [ ${incrementhr} -eq 0 ]; then
  echo "ERROR: increment hour (incrementhr) cannot be zero. Inifinite loop will result. Please modify. Exiting..."
  exit 1
fi

if [ ${copygb_opt} == 'awips' ]; then
   if [ -z ${awips_id} ]; then
      echo "ERROR: copygb_opt = '${copygb_opt}', must uncomment and set 'awips_id'. Exiting..."
      exit 1
   fi
fi

if [ ${copygb_opt} == 'custom' ]; then
   if [ -z ${custom_gds} ]; then
      echo "ERROR: copygb_opt = '${copygb_opt}', must uncomment and set 'custom_gds'. Exiting..."
      exit 1
   fi
fi

#----------------------------------------------------------------------
# End checks of user input
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#  Begin work
#----------------------------------------------------------------------

# cd to working directory
cd ${DOMAINPATH}/postprd
err1=$?
if test "$err1" -ne 0
then
echo "ERROR: Could not 'cd' to working directory. Did you create directory: '${DOMAINPATH}/postprd'?  \
Does '${DOMAINPATH}' exist?  Exiting... "
exit 1
fi

# Get local copy of parm file
# For GRIB1 the code uses wrf_cntrl.parm to select variables for output
#   the available fields are set at compilation
if [[ ${outFormat} == "grib" ]]; then
   if [[ ${dyncore} == "ARW" || ${dyncore} == "NMM" ]]; then
      ln -fs ${paramFile} wrf_cntrl.parm 
   elif [ ${dyncore} == "NMB" ]; then
      ln -fs ${paramFile} nmb_cntrl.parm
   fi
elif [[ ${outFormat} == "grib2" ]]; then
# For GRIB2 the code uses postcntrl.xml to select variables for output
#   the available fields are defined in post_avlbflds.xml -- while we
#   set a link to this file for reading during runtime it is not typical
#   for one to update this file, therefore the link goes back to the
#   program directory - this is true for params_grib2_tbl_new also - a
#   file which defines the GRIB2 table values
ln -fs ${xmlCntrlFile} postcntrl.xml
ln -fs ${txtCntrlFile} postxconfig-NT.txt
ln -fs ${UNIPOST_HOME}/parm/post_avblflds.xml post_avblflds.xml
ln -fs ${UNIPOST_HOME}/src/lib/g2tmpl/params_grib2_tbl_new params_grib2_tbl_new
fi

# Link microphysic's tables - code will use based on mp_physics option
# found in data
ln -fs ${UNIPOST_HOME}/parm/nam_micro_lookup.dat .
ln -fs ${UNIPOST_HOME}/parm/hires_micro_lookup.dat .

# link coefficients for crtm2 (simulated synthetic satellites)
CRTMDIR=${UNIPOST_HOME}/src/lib/crtm2/src/fix

ln -fs $CRTMDIR/EmisCoeff/MW_Water/Big_Endian/FASTEM6.MWwater.EmisCoeff.bin
ln -fs $CRTMDIR/EmisCoeff/IR_Ice/SEcategory/Big_Endian/NPOESS.IRice.EmisCoeff.bin   ./
ln -fs $CRTMDIR/EmisCoeff/IR_Snow/SEcategory/Big_Endian/NPOESS.IRsnow.EmisCoeff.bin ./
ln -fs $CRTMDIR/EmisCoeff/IR_Water/Big_Endian/Nalli.IRwater.EmisCoeff.bin           ./
ln -fs $CRTMDIR/EmisCoeff/IR_Land/SEcategory/Big_Endian/NPOESS.IRland.EmisCoeff.bin ./
ln -fs $CRTMDIR/EmisCoeff/IR_Water/Big_Endian/EmisCoeff.bin       ./
ln -fs $CRTMDIR/AerosolCoeff/Big_Endian/AerosolCoeff.bin     ./
ln -fs $CRTMDIR/CloudCoeff/Big_Endian/CloudCoeff.bin         ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/imgr_g11.SpcCoeff.bin    ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/imgr_g11.TauCoeff.bin    ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/imgr_g12.SpcCoeff.bin    ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/imgr_g12.TauCoeff.bin    ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/imgr_g13.SpcCoeff.bin    ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/imgr_g13.TauCoeff.bin    ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/imgr_g15.SpcCoeff.bin    ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/imgr_g15.TauCoeff.bin    ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/imgr_mt1r.SpcCoeff.bin    ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/imgr_mt1r.TauCoeff.bin    
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/imgr_mt2.SpcCoeff.bin    ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/imgr_mt2.TauCoeff.bin    
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/imgr_insat3d.SpcCoeff.bin    ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/imgr_insat3d.TauCoeff.bin    
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/amsre_aqua.SpcCoeff.bin  ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/amsre_aqua.TauCoeff.bin  ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/tmi_trmm.SpcCoeff.bin    ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/tmi_trmm.TauCoeff.bin    ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/ssmi_f13.SpcCoeff.bin    ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/ssmi_f13.TauCoeff.bin    ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/ssmi_f14.SpcCoeff.bin    ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/ssmi_f14.TauCoeff.bin    ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/ssmi_f15.SpcCoeff.bin    ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/ssmi_f15.TauCoeff.bin    ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/ssmis_f16.SpcCoeff.bin   ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/ssmis_f16.TauCoeff.bin   ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/ssmis_f17.SpcCoeff.bin   ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/ssmis_f17.TauCoeff.bin   ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/ssmis_f18.SpcCoeff.bin   ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/ssmis_f18.TauCoeff.bin   ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/ssmis_f19.SpcCoeff.bin   ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/ssmis_f19.TauCoeff.bin   ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/ssmis_f20.SpcCoeff.bin   ./
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/ssmis_f20.TauCoeff.bin   ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/seviri_m10.SpcCoeff.bin   ./   
ln -fs $CRTMDIR/TauCoeff/ODPS/Big_Endian/seviri_m10.TauCoeff.bin   ./
ln -fs $CRTMDIR/SpcCoeff/Big_Endian/v.seviri_m10.SpcCoeff.bin   ./   

#######################################################
# 1. Run Unipost
#
# The Unipost is used to read native WRF model 
# output and put out isobaric state fields and derived fields.
#######################################################

export NEWDATE=$startdate

while [ $((10#${fhr})) -le $((10#${lastfhr})) ] ; do

# Formatted fhr for filenames
fhr=`printf "%02i" ${fhr}`

NEWDATE=`${POSTEXEC}/ndate.exe +$((10#${fhr})) $startdate`

YY=`echo $NEWDATE | cut -c1-4`
MM=`echo $NEWDATE | cut -c5-6`
DD=`echo $NEWDATE | cut -c7-8`
HH=`echo $NEWDATE | cut -c9-10`

echo 'NEWDATE' $NEWDATE
echo 'YY' $YY

# Begin looping through domains list
# ie. for domain in d01 d02 d03
for domain in ${domain_list}
do

# Create model file name (inFileName)
dom_id=`echo "${domain}" | cut -d 'd' -f 2`
if [[ ${dyncore} == "ARW" || ${dyncore} == "NMM" ]]; then
   inFileName=${modelDataPath}/wrfout_d${dom_id}_${YY}-${MM}-${DD}_${HH}_00_00.nc
elif [ ${dyncore} == "NMB" ]; then
   inFileName=${modelDataPath}/nmmb_hst_${dom_id}_nio_00${fhr}h_00m_00.00s
fi

# Check if that file exists
if [[ ! -e ${inFileName} ]]; then
  echo "ERROR: Can't find 'inFileName': ${inFileName}. Directory or file does not exist.  Exiting..."
  echo "ERROR: Check if 'modelDataPath': ${modelDataPath} exists."
  if [[ ${dyncore} == "ARW" || ${dyncore} == "NMM" ]]; then
     echo "ERROR: Check if file: 'wrfout_d${dom_id}_${YY}-${MM}-${DD}_${HH}_00_00.nc' exists in modelDataPath."
  elif [ ${dyncore} == "NMB" ]; then
     echo "ERROR: Check if file: 'nmmb_hst_${dom_id}_nio_00${fhr}h_00m_00.00s' exists in modelDataPath."
  fi 
  exit 1
fi
   
# Create itag based on user provided info. 
# Output format now set by user so if-block below uses this
# to generate the correct itag. 

if [[ ${outFormat} == "grib" ]]; then

cat > itag <<EOF
${inFileName}
${inFormat}
${YY}-${MM}-${DD}_${HH}:00:00
${tag}
EOF

elif [[ ${outFormat} == "grib2" ]]; then

cat > itag <<EOF
${inFileName}
${inFormat}
${outFormat}
${YY}-${MM}-${DD}_${HH}:00:00
${tag}
EOF

else
echo "ERROR: output format 'outFormat=${outFormat}' not supported, must choose 'grib' or 'grib2'. Exiting..."
exit 1
fi

#-----------------------------------------------------------------------
#   Run unipost.
#-----------------------------------------------------------------------
rm fort.*

ln -sf ${paramFile} fort.14

#----------------------------------------------------------------------
# There are two environment variables tmmark and COMSP
# RUN the unipost.exe executable. 
#----------------------------------------------------------------------

${RUN_COMMAND} > unipost_${domain}.${fhr}.out 2>&1

#----------------------------------------------------------------------
# DEBUG Example, uncomment below and comment ${RUN_COMMAND} line above.

# debugger runs - enter your debugger and hour of error
#if [[ $((10#${fhr})) -eq 3 ]]; then
#  mpirun.dbg.totalview -progname ${POSTEXEC}/unipost.exe > unipost_${domain}.${fhr}.out 2>&1
#else
#  mpirun -np 1 ${POSTEXEC}/unipost.exe > unipost_${domain}.${fhr}.out 2>&1
#fi
#----------------------------------------------------------------------


# This prefix was given in the wrf_cntl.parm or nmb_cntl.parm file (GRIB1)
# or postcntrl.xml(GRIB2)

if [[ ${dyncore} == "ARW" || ${dyncore} == "NMM" ]]; then
   mv WRFPRS${fhr}.${tmmark} WRFPRS_${domain}.${fhr}
elif [ ${dyncore} == "NMB" ]; then
   mv NMBPRS${fhr}.${tmmark} NMBPRS_${domain}.${fhr}
fi

#
#----------------------------------------------------------------------
#   End of unipost job
#----------------------------------------------------------------------

# check to make sure UPP was successful and script linked the file
if [[ ${dyncore} == "ARW" || ${dyncore} == "NMM" ]]; then
    ls -l WRFPRS_${domain}.${fhr}
    err1=$?
elif [ ${dyncore} == "NMB" ]; then
    ls -l NMBPRS_${domain}.${fhr}
    err1=$? 
fi

if test "$err1" -ne 0
then

echo 'UNIPOST FAILED, EXITING'
exit

fi

#######################################################################
# EXAMPLES of running copygb
#######################################################################
# 
# Copygb interpolates Unipost output from its native 
# grid to a regular projection grid. The package copygb 
# is used to horizontally interpolate from one domain 
# to another, it is necessary to run this step for wrf-nmm 
# (but not for wrf-arw) because wrf-nmm's computational 
# domain is on rotated Arakawa-E grid. It is also necessary
# to run copygb for nmmb data to destagger the NMMB 
# forecasts from the staggered native B-grid to a regular 
# non-staggered grid.
#
# Copygb can be run in 3 ways as explained below. 
#
# NOTE: Ths section is providied as examples of the various ways to
# run copygb. The script automatically runs copygb on nmm and nmmb
# data based on user input above (copygb_opt). 
#
# There is no reason to uncomment or modify these examples unless
# you are experieneced and want to run copygb differently from
# the script options above in "User Edit Section". Note you will
# have to comment or delete or modify the default script commands 
# below if you are attempting to run copygb in another manner.
#
#----------------------------------------------------------------------
#
# Option 1: 
# Copygb is run with a pre-defined AWIPS grid 
# (variable $gridno, see below) Specify the grid to 
# interpolate the forecast onto. To use standard AWIPS grids 
# (list in  http://www.nco.ncep.noaa.gov/pmb/products/nam/ 
# or http://www.nco.ncep.noaa.gov/pmb/docs/on388/tableb.html),
# set the number of the grid in variable gridno below.
# To use a user defined grid, see explanation above copygb command.
#
# export gridno=212
#
#${POSTEXEC}/copygb.exe -xg${gridno} WRFPRS_${domain}.${fhr} wrfprs_${domain}.${fhr}
#
#----------------------------------------------------------------------
#
#  Option 2: 
#  Copygb ingests a kgds definition on the command line.
#${POSTEXEC}/copygb.exe -xg"255 3 109 91 37748 -77613 8 -71000 10379 9900 0 64 42000 42000" WRFPRS_${domain}.${fhr} wrfprs_${domain}.${fhr}
#
#----------------------------------------------------------------------
#
#  Option 3: 
#  Copygb can ingests contents of files too. For example:
#     copygb_gridnav.txt or copygb_hwrf.txt through variable $nav.
# 
#  Option -3.1:
#    To run for "Lambert Comformal map projection" 
#
#read nav < 'copygb_gridnav.txt'
#
#  Option -3.2:
#    To run for "lat-lon"
#
#read nav < 'copygb_hwrf.txt'
#
#export nav
#
# (For more info on "copygb" see UPP User's Guide - link at top of script)
#
#######################################################################
# End EXAMPLES Section
#######################################################################

if [[ $dyncore = "NMM"  || ${dyncore} == "NMB" ]]; then

if [[ ${outFormat} == "grib" ]]; then

#-------------------------------------------------------------------------------------
# 2. Run copygb if NMM or NMB model data.
#-------------------------------------------------------------------------------------
#  Set grid specs file to read based on user specifications (copygb_opt)
#  in User Edit Section at top of script.

if [[ ${copygb_opt} == "lambert" ]]; then
   read nav < 'copygb_gridnav.txt' 
   export nav
   echo "copygb_opt = ${copygb_opt}, using copygb_gridnav.txt to run copygb."
   echo $nav
elif [[ ${copygb_opt} == "lat-lon" ]]; then
   read nav < 'copygb_hwrf.txt' 
   export nav
   echo "copygb_opt = ${copygb_opt}, using copygb_hwrf.txt to run copygb."
   echo $nav
elif [[ ${copygb_opt} == "awips" ]]; then
   export nav=${awips_id}
   echo "copygb_opt = ${copygb_opt}, using awips_id=${awips_id} to run copygb."
   echo $nav
elif [[ ${copygb_opt} == "custom" ]]; then
   echo ${custom_gds} > 'copygb_custom.txt'
   read nav < 'copygb_custom.txt' 
   export nav
   echo "copygb_opt = ${copygb_opt}, using custom_gds=${custom_gds} to run copygb."
   echo $nav
fi

# Execute copygb with grid specs read into ${nav}
if [[ ${dyncore} == "NMM" ]]; then
   ${POSTEXEC}/copygb.exe -xg"${nav}" WRFPRS_${domain}.${fhr} wrfprs_${domain}.${fhr}
elif [ ${dyncore} == "NMB" ]; then
   ${POSTEXEC}/copygb.exe -xg"${nav}" NMBPRS_${domain}.${fhr} nmbprs_${domain}.${fhr}
fi

# Check to see whether "copygb" created the requested file.
if [[ ${dyncore} == "NMM" ]]; then
   ls -l wrfprs_${domain}.${fhr}
   err1=$?
elif [ ${dyncore} == "NMB" ]; then
   ls -l nmbprs_${domain}.${fhr}
   err1=$?
fi

if test "$err1" -ne 0
then

echo 'copygb FAILED, EXITTING'
exit

fi  # End test block for file

elif [[ ${outFormat} == "grib2" ]]; then
    echo "Warning: no destaggering done for grib2 output using copygb, see wgrib2 for regridding grib2 output"

fi # End if-block for if grib or grib2

#----------------------------------------------------------------------
#   End of copygb job
#----------------------------------------------------------------------

elif [ $dyncore = "ARW" ]; then
    mv WRFPRS_${domain}.${fhr} wrfprs_temp
    mv wrfprs_temp wrfprs_${domain}.${fhr}

fi # End if-block for if NMM or NMB or ARW

done 

fhr=$((10#${fhr}+$((${incrementhr}))))

NEWDATE=`${POSTEXEC}/ndate.exe +$((10#${fhr})) $startdate`

done

date
echo "End of Output Job"
exit
