"""Read-only ZIP intake audit. Generates review manifests, never approves unknown content.
Usage: python tools/audit_handoff.py --packages DIR --output DIR
"""
import argparse,collections,csv,hashlib,io,json,re,unicodedata,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def normalized(value):
 value=unicodedata.normalize('NFKC',str(value)).casefold()
 value=''.join(c for c in value if unicodedata.category(c)!='Mn')
 return re.sub(r'[^\w]+',' ',value).replace('أ','ا').replace('إ','ا').replace('آ','ا').strip()
def arithmetic(text):
 return bool(re.search(r'\d\s*[+×÷*/=]|\b(?:حاصل|ناتج|مجموع|الجذر|جذر|اضرب|اقسم|قسمة|متتالية|متتابعة|نصف العدد|ضعف العدد|العدد التالي|العدد الناقص|احسب|حسابية|عددي|عددية|العمليات الحسابية)\b',text))
def write(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
def audit(packages,output):
 output.mkdir(parents=True,exist_ok=True);summary={};sources=[]
 approved=json.loads((ROOT/'data/approved_content/questions.json').read_text(encoding='utf-8'))['questions'];approved_ids={q['id'] for group in approved.values() for q in group}
 old=json.loads((ROOT/'data/questions.json').read_text(encoding='utf-8'));old_text={normalized(q.get('ar','')):q['id'] for group in old.values() for q in group}
 question_rows=[];seen={};groups=collections.defaultdict(list)
 path=packages/'GamingHub_3000_Consolidated_Handoff.zip'
 with zipfile.ZipFile(path) as z:
  rows=json.loads(z.read('bank_3000_structurally_valid.json'))
  for q in rows:
   reasons=[];key=normalized(q['question_ar']);options=json.loads(q['options_ar']) if isinstance(q['options_ar'],str) else q['options_ar'];correct=int(q['correct_index'])
   if len(options)!=4 or len({normalized(x) for x in options})!=4 or not 0<=correct<4 or normalized(options[correct])!=normalized(q['correct_answer_ar']):reasons.append('INVALID_OPTION_MAPPING')
   if arithmetic(q['question_ar']):reasons.append('EXCLUDED_ARITHMETIC')
   if q['id'] in seen:reasons.append('DUPLICATE_ID')
   seen[q['id']]=True
   if key in old_text:reasons.append('EXACT_OLD_QUESTION_DUPLICATE:'+old_text[key])
   target='1' if q['category_id']=='cinema' else '3' if q['category_id']=='puzzles' else '5'
   if q.get('question_type')=='who_am_i':reasons.append('IDENTITY_CLUES_MAPPING_REVIEW_REQUIRED')
   decision='APPROVED' if q['id'] in approved_ids else 'REJECTED' if any(r.startswith(('INVALID','EXCLUDED','DUPLICATE','EXACT_OLD')) for r in reasons) else 'HOLD'
   if decision=='APPROVED' and reasons:raise ValueError('Approved question conflicts with audit: '+q['id']+repr(reasons))
   if decision=='HOLD':reasons+=['FACT_AND_SEMANTIC_REVIEW_REQUIRED','ENGLISH_TRANSLATION_REQUIRED']
   row={'id':q['id'],'question_ar':q['question_ar'],'category':q['category_id'],'proposed_existing_game':target,'decision':decision,'reasons':reasons,'difficulty':q['difficulty'],'difficulty_status':'EDITORIAL_NOT_PLAYER_CALIBRATED','normalized':key,'answer_key':normalized(q['correct_answer_ar'])}
   question_rows.append(row);groups[(q['category_id'],row['answer_key'])].append(row)
  # Semantic candidates remain HOLD until editorial adjudication, never auto-approved.
  pairs=[];stop={'ما','هو','هي','اي','في','من','اللي','ايه','اسم','الذي','التي','علي','على','عن','ده','هذه','هذا'}
  for items in groups.values():
   for i,a in enumerate(items):
    ta=set(a['normalized'].split())-stop
    for b in items[i+1:]:
     tb=set(b['normalized'].split())-stop;score=len(ta&tb)/max(1,len(ta|tb))
     if score>=.5:pairs.append({'a':a['id'],'b':b['id'],'token_jaccard':round(score,3),'same_answer':True,'decision':'EDITORIAL_CANDIDATE_NOT_FINAL'})
  write(output/'questions_review.json',question_rows);write(output/'semantic_candidates.json',pairs)
  summary['questions']={'provided':len(rows),'decisions':dict(collections.Counter(r['decision'] for r in question_rows)),'arithmetic_excluded':sum('EXCLUDED_ARITHMETIC' in r['reasons'] for r in question_rows),'semantic_candidates':len(pairs),'english_present_in_source':sum(bool(q.get('question_en')) for q in rows),'approved_actual_translations':len(approved_ids)}
 sources.append({'package':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
 audio_rows=[];path=packages/'GamingHub_GuessSound_Work_Handoff_158_Candidates.zip'
 mismatched={'SFX019','SFX027','SFX034','SFX035','SFX039','SFX042','SFX052','SFX053','SFX073','SFX075','SFX076','SFX094','SFX105','SFX109','SFX123','SFX124','SFX125','SFX127','SFX129','SFX132','SFX142','SFX150','SFX153','SFX154','SFX155','SFX156','SFX159','SFX160','SFX162','SFX172','SFX175','SFX183','SFX184','SFX185','SFX192','SFX193','SFX197','SFX198'}
 with zipfile.ZipFile(path) as z:
  for q in json.loads(z.read('data/sound_bank_review.json')):
   reasons=[];exists=q['audio'] in z.namelist();source=q.get('source_url','');title=source.split('/wiki/File:')[-1]
   if not exists:decision='MISSING';reasons.append('FILE_NOT_PROVIDED')
   else:
    raw=z.read(q['audio'])
    if hashlib.sha256(raw).hexdigest()!=q['sha256']:reasons.append('HASH_MISMATCH')
    if not raw.startswith(b'OggS'):reasons.append('NOT_OGG_CONTAINER')
    if not all(q.get(k) for k in ('source_url','license','author')):reasons.append('INCOMPLETE_LICENSE_EVIDENCE')
    if any(not x.strip() for x in q['choices_ar']) or not q.get('answer_ar'):reasons.append('MISSING_ARABIC_LABELS')
    if re.match(r'(En-|De-|Fr-|Nl-|NL-|Cs-|Pl-|Uk-|LL-Q)',title) or 'LibriVox' in title:reasons.append('SPEECH_OR_PRONUNCIATION_SOURCE_METADATA')
    if q['id'] in mismatched:reasons.append('SOURCE_DESCRIPTION_LABEL_MISMATCH')
    decision='REJECTED' if any(x in reasons for x in ('HASH_MISMATCH','NOT_OGG_CONTAINER','SPEECH_OR_PRONUNCIATION_SOURCE_METADATA','SOURCE_DESCRIPTION_LABEL_MISMATCH')) else 'HOLD'
    reasons+=['ACTUAL_AUDITION_REQUIRED','LICENSE_FILE_PROVENANCE_VERIFICATION_REQUIRED']
   audio_rows.append({**q,'decision':decision,'decision_basis':'PACKAGE_METADATA_AND_BYTES_NOT_AUDITION','review_reasons':reasons,'approved_for_release':False})
  summary['sounds']={'manifest_entries':len(audio_rows),'provided_files':sum(r['decision']!='MISSING' for r in audio_rows),'approved':0,'decisions':dict(collections.Counter(r['decision'] for r in audio_rows)),'missing_not_used':sum(r['decision']=='MISSING' for r in audio_rows)}
 write(output/'sounds_review.json',audio_rows);sources.append({'package':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
 path=packages/'GamingHub_Work_Handoff_Photos.zip'
 with zipfile.ZipFile(path) as z:
  with zipfile.ZipFile(io.BytesIO(z.read('sources/GamingHub_302_Images_Isolated_Staging.zip'))) as inner:
   rows=json.loads(inner.read('documentation/new_102/manifest_102.json'))
   write(output/'celebrity_102_hold.json',[{**q,'decision':'HOLD','reason':'No final commercial clearance; previous review preserved, not repeated'} for q in rows])
  extra=json.loads((output/'photo_decisions.json').read_text(encoding='utf-8'))
  summary['photos']={'original_preserved':200,'new_source_candidates':len(rows)+len(extra),'new_approved':sum(q['decision']=='APPROVED_DEVELOPMENT' for q in extra),'new_rejected_duplicate_subject':sum(q['decision']=='REJECTED_DUPLICATE_SUBJECT' for q in extra),'hold_existing_rights_review':len(rows),'expected_playable_development':228,'replacement_49_package':'NOT_PROVIDED_IN_THESE_ATTACHMENTS'}
 sources.append({'package':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()});write(output/'package_sources.json',sources);write(output/'SUMMARY.json',summary)
 return summary
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--packages',type=Path,required=True);p.add_argument('--output',type=Path,required=True);args=p.parse_args();print(json.dumps(audit(args.packages,args.output),ensure_ascii=False,indent=2))

