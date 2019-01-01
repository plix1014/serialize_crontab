# serialize_crontab

Expands all cron entries and displays in time sorted order.
To filter output, you could pipe it through a grep command.


### Prerequisites

Unix system with crontab files
Tested on Solaris and Linux


### Installing

Just copy the script to a path which is in the search path.

e.g.:
```
cp serialize_crontab.pl /usr/local/bin
```


## Script usage

some usage examples
```
crontab -l           | serialize_crontab.pl
crontab -u foobar -l | serialize_crontab.pl
crontab -l           | serialize_crontab.pl -as | egrep -v "foobar|barfoo"
serialize_crontab.pl -a < /etc/crontab
serialize_crontab.pl    < /etc/cron.d/anacron
serialize_crontab.pl -s < /etc/cron.d/foobar
```

### todays jobs

Sort all jobs which would run today
```
crontab -l | serialize_crontab.pl
```

### todays jobs with seperation lines

Sort all jobs which would run today displayed with a seperation line.
Indicates last and future events
```
crontab -l | serialize_crontab.pl -s
```

### all jobs 

All jobs sorted and expanded
```
crontab -l | serialize_crontab.pl -a
```

## Sample crontab and output

Examples with the supplied foobar.cron file

### todays foobar jobs

Sort all foobar jobs which would run today
```
serialize_crontab.pl < foobar.cron
# todays cronjobs: 
#    HH:MI     Day        Month      Weekday    Command
#    11:30     *          *          1-5	ksh -c '~/scripts/foofoo/foofoo.sh'
#    13:30     *          *          1-5	ksh -c '~/scripts/foofoo/foofoo.sh'
#    17:16     *          *      Mon-Thu	csh -c '~/scripts/foobar/foobar.sh'
#    17:22     *          *          1-5	csh -c '~/scripts/barfoo/barfoo.sh'
```

### todays foobar jobs with seperation lines

Sort all foobar jobs which would run today displayed with a seperation line.
Indicates last and future events
```
serialize_crontab.pl -s < foobar.cron
# todays cronjobs: 
#    HH:MI     Day        Month      Weekday    Command
#----------------- PAST -----------------------------------------------------------------------------------
#    11:30     *          *          1-5	ksh -c '~/scripts/foofoo/foofoo.sh'
#----------------  NOW  -----------------------------------------------------------------------------------
#                13:11:19
#---------------- FUTURE ----------------------------------------------------------------------------------
#    13:30     *          *          1-5	ksh -c '~/scripts/foofoo/foofoo.sh'
#    17:16     *          *      Mon-Thu	csh -c '~/scripts/foobar/foobar.sh'
#    17:22     *          *          1-5	csh -c '~/scripts/barfoo/barfoo.sh'
```

### all foobar jobs 

All foobar jobs sorted and expanded
```
serialize_crontab.pl -a < foobar.cron
# all cronjobs: 
#    HH:MI     Day        Month      Weekday    Command
#    05:55     *        Nov          2-6	csh -c '~/scripts/barbar/barbar.sh'
#    11:30     *          *          1-5	ksh -c '~/scripts/foofoo/foofoo.sh'
#    13:30     *          *          1-5	ksh -c '~/scripts/foofoo/foofoo.sh'
#    17:15     1       6,12            *	csh -c '~/scripts/barfoobar/barfoobar.sh'
#    17:16     *          *      Mon-Thu	csh -c '~/scripts/foobar/foobar.sh'
#    17:22     *          *          1-5	csh -c '~/scripts/barfoo/barfoo.sh'
```


### all foobar jobs 

All foobar jobs sorted and expanded and displayed with a seperation line.
```
serialize_crontab.pl -as < foobar.cron
# all cronjobs: 
#    HH:MI     Day        Month      Weekday    Command
#----------------- PAST -----------------------------------------------------------------------------------
#    05:55     *        Nov          2-6	csh -c '~/scripts/barbar/barbar.sh'
#    11:30     *          *          1-5	ksh -c '~/scripts/foofoo/foofoo.sh'
#----------------  NOW  -----------------------------------------------------------------------------------
#                13:11:24
#---------------- FUTURE ----------------------------------------------------------------------------------
#    13:30     *          *          1-5	ksh -c '~/scripts/foofoo/foofoo.sh'
#    17:15     1       6,12            *	csh -c '~/scripts/barfoobar/barfoobar.sh'
#    17:16     *          *      Mon-Thu	csh -c '~/scripts/foobar/foobar.sh'
#    17:22     *          *          1-5	csh -c '~/scripts/barfoo/barfoo.sh'
```

## Author

* **plix1014** - *Initial work* - [plix1014](https://github.com/plix1014)

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.


## License

This project is licensed under the Attribution-NonCommercial-ShareAlike 4.0 International License - see the [LICENSE.md](LICENSE.md) file for details


## Acknowledgments

documentation is also available als POD.

```
perldoc serialize_crontab.pl
```

