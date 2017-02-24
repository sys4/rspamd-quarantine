CREATE TABLE IF NOT EXISTS meta (
	qid 		char(30) CONSTRAINT firstkey PRIMARY KEY,
	timestamp	timestamp,
	score		double precision,
	ip		inet,
	action		char(20),
	"from"		bytea,
	symbols		json
);

CREATE TABLE IF NOT EXISTS msg (
	qid		char(30) references meta(qid),
	content		text
);

