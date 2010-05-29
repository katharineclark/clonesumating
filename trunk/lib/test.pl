use mail;


$message = new mail;
$message->set('From','notepasser@notepasser.consumating.com');
$message->set('to','benjamin.brown@cnet.com');
$message->set('subject','this is a test');
$message->set('body','hello jerkpot!');
$message->send();

