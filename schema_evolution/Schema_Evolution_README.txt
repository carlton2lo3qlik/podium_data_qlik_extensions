7/10/2018

This document describes how to invoke the script load_data_schema_evolution.sh.

It also requires that the perl script log_status_parser be in the same directory.

There are several places within the script that need to be modified to work in your environment.  They are labeled with the following comment: "### Make Changes Here"

if the script is executed with no parameters, you will receive the following Usage message:

USAGE:
	load_data_schema_evolution_a.sh -s sourcename -e entityname
	Both -s sourcename and -e entityname must be provided
	

The result of an execution when a schema change is detected is that the existing version of the entity will be renamed by adding the current date, formatted as: _YYYYMMDD, to the end of the name.  The object with the current schema definition will be added to Podium and a data load will be executed.
