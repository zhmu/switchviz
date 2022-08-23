#!/usr/bin/perl -w

use strict;
use lib "/root/switch-scripts";

# destination path for all generated HTML pages
our $HTML_DIR = "/root/switch-scripts/www";

# destination path for all generated images
our $IMG_DIR = $HTML_DIR . "/images";

# path for temporary files
our $TMP_DIR = "/tmp";

# location of the dot(1) utility, as supplied with GraphViz, and
# location of severnal base utilities.
our $DOT = "/usr/local/bin/dot";
our $GREP = "/usr/bin/grep";
our $MV = "/bin/mv";
our $DIFF = "/usr/bin/diff";

# tftp server to store the configs on
our $TFTP_HOST = "1.2.3.4";

# switch path configs config on the server
our $CONFIG_PATH = "/tftpboot";

# password used to fetch the configuration from each switch
our $SWITCH_PASSWD = "...";

# location of the templates
$ENV{"HTML_TEMPLATE_ROOT"} = "/root/switch-scripts/templates";

1;

# vim:set ts=2 sw=2:
