#!/bin/bash
export SMARTBACKUP_VERSION=1.0
export DATABASE=
export DB_EXISTS=
export DOBACKUP=no
export SAVEPATH=
export INCLUDEPATTERN=
export DESTINATIONDIR=~/backup
export ARCHIVENAME=
export TEMPDIR=~/tmp
export VERSIONCONTROL=
export REMOVE=false
for i in "$@"
do
case $i in
    -a=*|--archivename=*)
    ARCHIVENAME="${i#*=}"
    shift # past argument=value
    ;;
    -b=*|--backup=*)
    BACKUP="${i#*=}"
    if [ -v BACKUP ] && [ ${BACKUP} = "yes" ] ; then
	echo "Backup command specified."
	export DOBACKUP=yes
    else
        echo "Backup command was not specified, operation aborts."
	export DOBACKUP=no
    fi
    shift # past argument=value
    ;;
    -c=*|--createdb=*)
    CREATEDB="${i#*=}"
    shift # past argument=value
    ;;
    -d=*|--destinationdir=*)
    DESTINATIONDIR="${i#*=}"
    shift # past argument=value
    ;;
    -D=*|--database=*)
    DATABASE="${i#*=}"
    if [ -v DATABASE ] || [ ${#DATABASE} != 0 ] ; then
	echo "Database was specified. Version control is enabled."
        export VERSIONCONTROL=true
	if [ `sudo mysql -Bse "show databases" | grep -q "$DATABASE"` ]; then
		export DB_EXISTS="true";
	else
		export DB_EXISTS="false";
	fi
    else
	echo "Database was not specified. Version control is disabled."
	export VERSIONCONTROL=false
    fi
    shift # past argument=value
    ;;
    -i=*|--include=*)
    INCLUDEPATTERN="${i#*=}"
    if [ ! -v INCLUDEPATTERN ] || [ ${#INCLUDEPATTERN} = 0 ] ; then
	echo "File name pattern was not specified, default is *"
	export INCLUDEPATTERN=*
    fi
    shift # past argument=value
    ;;
    -P=*|--path=*)
    SAVEPATH="${i#*=}"
    shift # past argument=value
    ;;
    -R=*|--remove-temp-files=*)
    REMOVETEMPFILES="${i#*=}"
    if [ -v REMOVETEMPFILES ] && [ ${REMOVETEMPFILES} == "yes" ] ; then
	echo "Temporary files will be erased."
	export REMOVE=true
    else
        echo "Temporary files will be kept."
	export REMOVE=false
    fi
    shift # past argument=value
    ;;
    -T=*|--tempdir=*)
    TEMPDIR="${i#*=}"
    shift # past argument=value
    ;;
    --help)
	echo "smartbackup V$SMARTBACKUP_VERSION"
	echo ""
	echo "command line parameters"
	echo ""
	echo "	-a= | --archivename=nameOfArchive "
	echo "	-b= | --backup=yes"
	echo "	-c= | --createdb=yes"
	echo "	-d= | --destinationdir=destinationDir"
	echo "	-D= | --database=databaseName"
	echo "	-i= | --include=includePattern"
	echo "	-P= | --path=pathToBeArchived"
	echo "	-R= | --remove-temp-files=yes"
	echo "	-T= | --tempdir=temporaryDirectory"
	echo ""
	echo "Version control is enabled when the database parameter is set."
	echo ""
	echo "(C) Peter Pfandler"
    shift # past argument with no value
    ;;
    *)
          # unknown option
    ;;
esac
done
export IFS=$'\n';
    if [ ! -v ARCHIVENAME ] || [ ${#ARCHIVENAME} = 0 ] ; then
	echo "Archive file name was not specified, default is archive"
	export ARCHIVENAME=archive
    fi
    export SAVENAME=$ARCHIVENAME;
    export BACKUP="backup_$ARCHIVENAME";
    if [ ! -v SAVEPATH ] || [ ${#SAVEPATH} = 0 ] ; then
	echo "Path was not specified, default is ~"
	export SAVEPATH=~
    fi
    if [ ! -e $TEMPDIR ] ; then
	echo "Temporary directory does not exist, creating it. ($TEMPDIR)"
        mkdir -p $TEMPDIR
    fi
    if [ ! -e $DESTINATIONDIR ] ; then
	echo "Destination directory does not exist, creating it. ($DESTINATIONDIR)"
	mkdir -p $DESTINATIONDIR
    fi
#Check if DB exists
if [ -v $CREATEDB ]; then
	test "$CREATEDB" == "yes"
fi
if [ $? == 0 ]; then
	echo "Creating Backup Database"
fi
if [ $DOBACKUP = "yes" ]; then
	echo "Starting Backup"
	if [ -e $TEMPDIR/$SAVENAME ]; then
		echo "Deleting temporary files..."
		rm $TEMPDIR/$SAVENAME;
	fi
	if [ -e $TEMPDIR/$BACKUP ]; then
		echo "Deleting temporary files..."
	    rm $TEMPDIR/$BACKUP;
	fi
	for alma in `find $SAVEPATH/$INCLUDEPATTERN -type f`;
	#do export korte=`echo $alma|sed -e ":a;s/e/\&/;t a;"`;
	do export filename=$alma;
	export filedate=`/bin/ls --full-time --time-style=long-iso $alma | awk ' {printf "%s%s\n",$6,$7} ' | sed 's/:/_/g'`;
	echo $filedate;
	if [ "$VERSIONCONTROL" == "true" ]; then
		export nameanddate=`mysql -Bse "use savefile;select count(*) from file where ((datum = '$filedate') and (nev = '$filename'))"`;
		export onlyname=`mysql -Bse "use savefile;select count(*) from file where (nev = '$filename')"`;
	else
		export nameanddate=0;
		export onlyname=0;
	fi
	if [ "$nameanddate" == "0" ]; then
	    echo $alma >>$TEMPDIR/$SAVENAME;
	    if [ "$onlyname" != "0" ]; then
	        echo $DESTINATIONDIR"$alma" >>$TEMPDIR/$BACKUP;
	    fi;
	    if [ "$VERSIONCONTROL" == "true" ]; then
		mysql -Bse "use savefile;insert into file (nev,datum) values ('$filename','$filedate');";
	    fi
	fi;
	done
	export IFS=$' \t\n';
	#backup previous version of the files
	if [ -e $TEMPDIR/$BACKUP ]; then
		echo "cpio -d -m -p $DESTINATIONDIR/$ARCHIVENAME/backup <$TEMPDIR/$BACKUP"
		cpio -d -m -p $DESTINATIONDIR/$ARCHIVENAME/backup <$TEMPDIR/$BACKUP
	fi
	#overwrite backup with the newest files
	if [ -e $TEMPDIR/$SAVENAME ]; then
	echo "cpio -d -m -p $DESTINATIONDIR/$ARCHIVENAME <$TEMPDIR/$SAVENAME"
	cpio -d -m -p $DESTINATIONDIR/$ARCHIVENAME <$TEMPDIR/$SAVENAME
	fi
	if [ ${REMOVE} == "true" ] && [ -e $TEMPDIR ]; then
	    rm -rf $TEMPDIR
	fi
	echo "Backup finished."
else
	echo "WARNING: Backup command not specified. Dry run."
fi

