use DBModule;

package DBModule::userSessions;
use vars qw(@ISA);
@ISA = qw(DBModule);
sub getFields {qw(id userId startDate lastAction firstLoad pageCount ip_address user_agent)}
sub setFields {qw(userId startDate lastAction firstLoad pageCount ip_address user_agent)}
sub tablename {qq(userSessions)}
1;
