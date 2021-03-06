#!/usr/bin/env bash
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved.
#
# Ingest clinical studies from the aact db to a csv file.
# All trials are ingested addressing cancer conditions.
#
# ./script/ingest.sh

set -eu

OUTPUT="data/input/clinical_trials.csv"
DB=aact

QUERY() {
  echo "\COPY (
  with cancer_trials as (select  distinct s.nct_id,s.brief_title AS title,
	s.start_date,
	s.overall_status,
	s.phase,
	s.enrollment,
	s.enrollment_type,
	
	s.study_type,
	s.number_of_arms,
	s.number_of_groups,
	s.why_stopped,
	s.has_dmc,
	s.is_fda_regulated_drug,
	s.is_fda_regulated_device,
	s.is_unapproved_device,
	s.is_ppsd,
	s.is_us_export
	
from ctgov.studies s
inner join ctgov.conditions c
on s.nct_id=c.nct_id
where 
(c.downcase_name like '%cancer%'
or c.downcase_name like '%neoplasm%'
or c.downcase_name like '%tumor%'
or c.downcase_name like '%malignancy%'
or c.downcase_name like '%oncology%'
or c.downcase_name like '%neoplasia%'
or c.downcase_name like '%neoplastic%')
),

conditions as (
SELECT
c.nct_id,
STRING_AGG(c.name, '|' ORDER BY name) AS conditions
FROM cancer_trials t
inner join ctgov.conditions c
on t.nct_id=c.nct_id	
GROUP BY
c.nct_id	
),

sponsors as (
select 
s.nct_id,
STRING_AGG(s.name, '|' ORDER BY name) AS lead_sponsor
	
from ctgov.sponsors s
where s.lead_or_collaborator='lead'	
group by s.nct_id	
)

select 
t.nct_id AS \"#nct_id\",
t.title,
CASE WHEN cv.has_us_facility THEN 'true' ELSE 'false' END AS has_us_facility,
c.conditions,
e.criteria AS eligibility_criteria

, t.start_date, s.lead_sponsor, b.description as summary, t.overall_status, t.phase, t.enrollment, t.enrollment_type, t.study_type, t.number_of_arms, t.number_of_groups, t.why_stopped, t.has_dmc, t.is_fda_regulated_drug, t.is_fda_regulated_device, t.is_unapproved_device, t.is_ppsd, t.is_us_export

from cancer_trials t

inner join conditions c
on t.nct_id=c.nct_id

left join ctgov.calculated_values cv
on cv.nct_id=t.nct_id

left join ctgov.eligibilities e
on e.nct_id=t.nct_id

left join sponsors s
on s.nct_id=t.nct_id

left join ctgov.brief_summaries b
on b.nct_id=t.nct_id

  )
  TO STDOUT WITH (FORMAT csv, HEADER)
  "
}

# Extract cancer related trials
psql -U "$USER" -d "$DB" -c "$(QUERY "SIMILAR TO")" > "$OUTPUT"

wc -l "$OUTPUT"