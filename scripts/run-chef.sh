#!/usr/bin/env bash
ROLE=`cat /etc/rm-role`
/bin/sh -c 'chef-solo -c /etc/chef/codedeploy/solo.rb -o "role[$1]"' -- "$ROLE"
