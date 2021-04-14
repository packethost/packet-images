/* 
 * Abbreviated version of the yacc grammar used by at(1).
 */

%token  <charval> DOTTEDDATE
%token  <charval> HYPHENDATE
%token  <charval> HOURMIN
%token  <charval> INT1DIGIT
%token  <charval> INT2DIGIT
%token  <charval> INT4DIGIT
%token  <charval> INT5_8DIGIT
%token  <charval> INT
%token  NOW
%token  AM PM
%token  NOON MIDNIGHT TEATIME
%token  SUN MON TUE WED THU FRI SAT
%token  TODAY TOMORROW
%token  NEXT
%token  MINUTE HOUR DAY WEEK MONTH YEAR
%token  JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC
%token  UTC

%type <charval> concatenated_date
%type <charval> hr24clock_hr_min
%type <charval> int1_2digit
%type <charval> int2_or_4digit
%type <charval> integer
%type <intval> inc_dec_period
%type <intval> inc_dec_number
%type <intval> day_of_week

%start timespec
%%
timespec        : spec_base
		| spec_base inc_or_dec
                ;

spec_base	: date
		| time
                | time date
                | NOW
		;

time		: time_base
		| time_base timezone_name
                ;

time_base	: hr24clock_hr_min
		| time_hour am_pm
		| time_hour_min
		| time_hour_min am_pm
		| NOON
                | MIDNIGHT
		| TEATIME
		;

hr24clock_hr_min: INT4DIGIT
		;

time_hour	: int1_2digit
		;

time_hour_min	: HOURMIN
		;

am_pm		: AM
		| PM
		;

timezone_name	: UTC
		;

date            : month_name day_number
                | month_name day_number year_number
                | month_name day_number ',' year_number
                | day_of_week
                | TODAY
                | TOMORROW
		| HYPHENDATE
		| DOTTEDDATE
		| day_number month_name
		| day_number month_name year_number
		| month_number '/' day_number '/' year_number
		| concatenated_date
                | NEXT inc_dec_period		
		| NEXT day_of_week
                ;

concatenated_date: INT5_8DIGIT
		;

month_name	: JAN | FEB | MAR | APR | MAY | JUN
		| JUL | AUG | SEP | OCT | NOV | DEC
		;

month_number	: int1_2digit
		;

day_number	: int1_2digit
		;

year_number	: int2_or_4digit
		;

day_of_week	: SUN | MON | TUE | WED | THU | FRI | SAT
		;

inc_or_dec	: increment | decrement
		;

increment       : '+' inc_dec_number inc_dec_period
                ;

decrement	: '-' inc_dec_number inc_dec_period
		;

inc_dec_number	: integer
		;

inc_dec_period	: MINUTE | HOUR | DAY | WEEK | MONTH | YEAR
		;

int1_2digit	: INT1DIGIT | INT2DIGIT
		;

int2_or_4digit	: INT2DIGIT | INT4DIGIT
		;

integer		: INT | INT1DIGIT | INT2DIGIT | INT4DIGIT | INT5_8DIGIT
		;

%%
