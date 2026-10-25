"""Server-owned family-friendly Party Room challenges and scoring helpers."""
import json, math, unicodedata
MISSIONS=("اجعل لاعبًا آخر يذكر اسم فاكهة دون إخباره بمهمتك", "اجعل لاعبًا يضحك بقصة قصيرة مناسبة للجميع", "اجعل لاعبًا يقول اسم مدينة في حديث طبيعي", "قدّم مجاملة لطيفة للاعبين دون كشف المهمة")
TRUTH=("ما هوايتك المفضلة؟", "احكِ موقفًا مضحكًا مناسبًا للجميع", "ما المكان الذي تحب زيارته؟")
DARE=("قل اسمك بصوت روبوت", "قل ثلاثة أسماء فاكهة خلال خمس ثوانٍ", "قل جملة لطيفة لكل لاعب")
def challenge(game, index):
    if game=='pass_the_bomb': return {'prompt':'القنبلة مع اللاعب المحدد: أرسل كلمة واحدة مختلفة تبدأ بحرف ب أو b خلال 15 ثانية', 'seconds':15}
    if game=='whos_most_likely':return {'prompt':('مين أكتر حد ممكن يسافر حول العالم؟','مين أكتر حد ممكن يفتح مطعمًا؟')[index%2]}
    if game=='odd_one_out':return {'prompt':'أي عنصر مختلف عن بقية المجموعة؟','choices':{'A':'تفاحة','B':'جزر','C':'موز','D':'عنب'}}
    if game=='crazy_emoji':return {'prompt':'خمن التعبير: 🦁 👑'}
    if game=='fake_it':return {'prompt':'اكتب معلومة خادعة مقنعة: ما أكبر كوكب في المجموعة الشمسية؟'}
    if game=='truth_or_dare':return {'prompt':'اختر حقيقة أو تحديًا، نفّذه، ثم يراجع المضيف إتمامه'}
    if game=='draw_disaster':return {'prompt':'ارسم قطة بخطوط بسيطة، ثم صوّت لرسم لاعب آخر'}
    return {'prompt':'مهمتك سرية. نفّذها دون كشفها، ثم يراجع المضيف إتمامها'}
def normalize(text):
    return ''.join(c for c in unicodedata.normalize('NFKC',text).casefold() if c.isalnum()).replace('أ','ا').replace('إ','ا').replace('آ','ا')
def drawing(text):
    try: strokes=json.loads(text)
    except (ValueError,TypeError):raise ValueError('invalid_drawing')
    if not isinstance(strokes,list) or not 1<=len(strokes)<=32:raise ValueError('invalid_drawing')
    total=0
    for stroke in strokes:
        if not isinstance(stroke,list) or len(stroke)<2:raise ValueError('invalid_drawing')
        total+=len(stroke)
        for point in stroke:
            if not isinstance(point,list) or len(point)!=2 or any(type(v) not in (int,float) or not math.isfinite(v) or not 0<=v<=1 for v in point):raise ValueError('invalid_drawing')
    if total>180:raise ValueError('drawing_too_large')
    return strokes
