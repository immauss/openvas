###############################################################################
# OpenVAS Vulnerability Test
# $Id: gb_wmi_access.nasl 10421 2018-07-05 12:17:22Z cfischer $
#
# Check for access via WMI
#
# Authors:
# Adrian Steins <adrian.steins@greenbone.net>
# Christian Fischer <christian.fischer@greenbone.net>
#
# Copyright:
# Copyright (C) 2017 Greenbone Networks GmbH, https://www.greenbone.net
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
###############################################################################

if(description)
{
  script_oid("1.3.6.1.4.1.25623.1.0.108205");
  script_version("$Revision: 10421 $");
  script_tag(name:"last_modification", value:"$Date: 2018-07-05 14:17:22 +0200 (Thu, 05 Jul 2018) $");
  script_tag(name:"creation_date", value:"2017-08-09 13:47:59 +0200 (Wed, 09 Aug 2017)");
  script_tag(name:"cvss_base", value:"0.0");
  script_tag(name:"cvss_base_vector", value:"AV:N/AC:L/Au:N/C:N/I:N/A:N");
  script_name("Check for access via WMI");
  script_category(ACT_GATHER_INFO);
  script_copyright("Copyright (C) 2017 Greenbone Networks GmbH");
  script_family("Windows");
  script_dependencies("toolcheck.nasl", "smb_login.nasl", "smb_nativelanman.nasl", "netbios_name_get.nasl");
  script_require_ports(139, 445);
  script_mandatory_keys("Tools/Present/wmi", "SMB/password", "SMB/login");
  script_exclude_keys("SMB/samba");

  script_tag(name:"summary", value:"This routine checks if an access to the remote host with the Windows Management Instrumentation (WMI)
  method is possible by using the provided SMB login/password credentials.");

  script_tag(name:"qod_type", value:"remote_banner");

  exit(0);
}

include("smb_nt.inc");

host = "192.168.1.88";
usrname = "desktop-6p84ror\\ge scott knauss";
passwd = "!!4everm0re";

if( kb_smb_is_samba() ) exit( 0 );

#host    = get_host_ip();
#usrname = kb_smb_login();
#passwd  = kb_smb_password();

display ("Starting");
if( ! host || ! usrname || ! passwd ) exit( 0 );

display(host);
display(usrname);
display(passwd);
# The user hasn't filled out a login so no need
# to check if WMI access is possible.
if( ! strlen( usrname ) > 0 ) exit( 0 );

display("Username is not blank");
domain = kb_smb_domain();
if( domain ) usrname = domain + '\\' + usrname;

display("About to WMI Connect");
handle = wmi_connect( host:host, username:usrname, password:passwd );
display("Finished connecting");
if( ! handle ) exit( 0 );

display("Yeeha - we connected");
wmi_close( wmi_handle:handle );

set_kb_item( name:"WMI/access_successful", value:TRUE );
set_kb_item( name:"SMB_or_WMI/access_successful", value:TRUE );

exit( 0 );

