use DBModule;

package DBModule::tag;
use vars qw(@ISA);
@ISA = qw(DBModule);
sub getFields {qw(id value parent facetId insertDate addedBy quirkyness)}
sub setFields {qw(value parent facetId insertDate addedBy quirkyness)}
sub tablename {qq(tag)}

1;

package DBModule::tagRef;

use vars qw(@ISA);
@ISA = qw(DBModule);
sub getFields {qw(profileId tagId source addedById dateAdded id facetId)}
sub setFields {qw(profileId tagId source addedById dateAdded id facetId)}
sub tablename {qq(tagRef)}

1;


