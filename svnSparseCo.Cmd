@Echo Off
::
:: PURPOSE : The script svn-spars checkout per config file
::            support of config changes: additions, changes of depth level.
::
:: USAGE   :  svnSparseCo.cmd <branch name> [<root checkout directory>]
::                  , if not defined  <root checkout directory>, assume <branch name>
::
Setlocal EnableDelayedExpansion

Set CONF=svnrules.conf

::Set USERNAME=BUILDBOT
:: Uncomment the PASSWORD to ask for it interactivelly when do initial co.
::  some paths may be external repos wich require credentials
::Set PASSWORD=blabla

Set SVN_ADD_ARGS=--config-option config:miscellany:use-commit-times=yes
Set BRANCH_SUBDIR_ROOT=

If Not Exist %CONF% (
    Echo [ERROR] cant find %CONF% in current directory [ %cd% ]
    Echo run the script from the %CONF% home
    Exit /b 1
)


If %1.==. (
    Echo.
    Echo Usage: %~nx0 ^<branch^> [^<checkout rootdir^>]
    Echo Examples: 
    Echo   %nx~0 master
    Echo       - will checkout master branch to master directory
    Echo   %nx~0 master slot1
    Echo       - will checkout master branch to slot1 directory                
    Exit /b 1
)
Set BRANCH=%1

If %2.==. (
    Set CHECKOUT_ROOT=%1
) Else (
    Set CHECKOUT_ROOT=%2
)

Echo [INFO] Set co rootdir to !CHECKOUT_ROOT!

::
:: Load vars from config
::
Echo [INFO] sparse checkouts config :: !cd!\%CONF%
Set SPIDX=-1
For /F "eol=# tokens=1,2,3" %%a In (%CONF%) Do (
    If %%a.==path. (
        Set /A SPIDX+=1
        Set SPARSE_PATH[!SPIDX!]=%%b %%c
    ) Else (
        Set %%a=%%b
    )
)
Echo [INFO] checkout root path :: !SVNROOT!/!BRANCH!!BRANCH_SUBDIR_ROOT!


::
:: Exit on already have branch svn co'ed unless -f given
::
If Not Exist !CHECKOUT_ROOT!\.svn (
    If Not Exist !CHECKOUT_ROOT! mkdir !CHECKOUT_ROOT!
    Cd /d !CHECKOUT_ROOT!
    Echo [INFO] initiating working directory at !cd!
    if Defined PASSWORD (
        svn co %SVN_ADD_ARGS% --depth empty^
             --username %USERNAME% --password %PASSWORD%^
             %SVNROOT%/%BRANCH%%BRANCH_SUBDIR_ROOT% !cd!
     ) Else (
        svn co %SVN_ADD_ARGS% --depth empty^
            --username %USERNAME%^
            %SVNROOT%/%BRANCH%%BRANCH_SUBDIR_ROOT% !cd!
     )
) Else (
    Cd /d !CHECKOUT_ROOT!
)

::
:: обновить вложенные каталоги с законфигуренным depth
::
For /L %%i In (0,1,!SPIDX!) Do Call :_co !SPARSE_PATH[%%i]!


Echo [INFO] done
Exit /b 0


::  Выполняет svn up для подкаталога
::  %1 - подкаталог для апдейта
::  %2 - уровень апдейта
:svn_up
    if Defined PASSWORD (
        svn up %SVN_ADD_ARGS% --set-depth %2^
            --username %USERNAME% --password %PASSWORD%^
            %1 || Call :_die some shit happened when svn up %1
    ) Else (
        svn up %SVN_ADD_ARGS% --set-depth %2^
            %1 || Call :_die some shit happened when svn up %1
    )
Goto :Eof


::  Проверяет нужно ли запустить svn up 
::  %1 - подкаталог для апдейта
::  %2 - уровень апдейта
::    Мы не можем тупо каждый раз чекаутить по конфигу, иначе
::     каждый раз каталоги будут усасываться начиная с empty
::     поэтому апдейтим только то чего еще нет или если depth изменился в конфиге
:_co
    If %2.==. Call :_die specify sparse value for --depth

    If Not Exist %1 (
        Echo [INFO] updating %1 with "%2" depth
        Call :svn_up %1 %2
    ) Else (
        svn info --xml %1 | FindStr "<depth>" | FindStr "%2" >nul
        If !errorlevel! NEQ 0 (
             echo [WARN] %1 depth changed to %2. re-checking out it...
             Call :svn_up %1 %2
        ) Else (
             Echo [INFO] %1 :: %2
        )
    )

    GoTo :Eof

:_die
    Echo [ERROR] %*
    Exit 1



#####################################################################################
# Here comes the svnrules.conf sample
#####################################################################################
#
# usage: just run c:\buildtools\svnSparseCo.Cmd <branch name> standing in my directory
#
#
# [must]
SVNROOT svn://depot/cosmosim
#
# [optional]
BRANCH_SUBDIR_ROOT /work_version/web_adm
# <subdirs of the branches>    <sparse rules for --depth>, define them consequently
#
path bin         files
path www         empty
path www/mailer  files
path www/img     infinity
