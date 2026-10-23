"""Deterministic projection of published general guidance onto released BIL IDs.

This does not create media identities or certify medical rehabilitation. See
the source scope and explicit BIL choices recorded in the generated artifact.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DESTINATION = ROOT / 'artifacts/workout_media/home_smart_plan_prescriptions_v1.json'
WARMUPS = ROOT / 'artifacts/workout_media/smart_plan_warmups_v1.json'


def build():
    catalog = json.loads((ROOT / 'artifacts/workout_media/workout_discovery_catalog_v1.json').read_text(encoding='utf-8'))
    home = {row['id']: row for row in catalog['items'] if row['_release_bundle_id'] == 'home-training'}
    sessions = []
    for level in ('beginner', 'regular', 'experienced'):
        squat = 'chair-squat' if level == 'beginner' else 'air-squat'
        push = {'beginner': 'wall-push-up', 'regular': 'counter-incline-push-up', 'experienced': 'standard-push-up'}[level]
        for variant in ('a', 'b', 'dumbbells', 'kettlebell'):
            if level == 'beginner' and variant in ('dumbbells', 'kettlebell'):
                continue
            hinge = {
                'dumbbells': 'resistance-full-body-dumbbell-deadlift-to-row-technique',
                'kettlebell': 'resistance-full-body-kettlebell-deadlift-technique',
            }.get(variant, 'home-bodyweight-bodyweight-hip-hinge-standard')
            ids = [
                f'home-bodyweight-{squat}-standard',
                f'home-bodyweight-{push}-standard',
                hinge,
                'home-bodyweight-prone-y-raise-standard',
                'home-bodyweight-dead-bug-standard' if variant == 'b' else 'home-bodyweight-glute-bridge-standard',
                'home-bodyweight-standing-calf-raise-standard',
            ]
            rows = []
            for exercise_id in ids:
                movement = home[exercise_id]  # Fail on missing or foreign IDs.
                rows.append({
                    'exerciseId': exercise_id,
                    'sourceName': movement['title'],
                    'titleAr': {
                        'Chair squat': 'القرفصاء باستخدام كرسي',
                        'Air squat': 'القرفصاء بوزن الجسم',
                        'Wall push-up': 'تمرين الضغط على الحائط',
                        'Counter incline push-up': 'تمرين الضغط المائل على سطح ثابت',
                        'Standard push-up': 'تمرين الضغط',
                        'Bodyweight hip hinge': 'ثني الورك بوزن الجسم',
                        'Prone Y raise': 'رفع الذراعين بوضعية Y من الانبطاح',
                        'Dead bug': 'مدّ الذراع والساق المتعاكسين من الاستلقاء',
                        'Glute bridge': 'جسر الأرداف',
                        'Standing calf raise': 'رفع الكعبين من الوقوف',
                        'Dumbbell deadlift to row': 'الرفعة الأرضية والسحب بالأوزان اليدوية',
                        'Kettlebell deadlift': 'الرفعة الأرضية بالكرة الحديدية',
                    }[movement['title']],
                    'equipment': movement['equipment'],
                    'sets': 3 if level == 'experienced' else 2,
                    'repetitions': '8-12 each side' if exercise_id == 'home-bodyweight-dead-bug-standard' else '8-12',
                    'restSeconds': 120,
                    'doseSourceIds': ['nhs-strength-frequency-2026', 'cdc-pcd-strength-rest-2014'],
                })
            sessions.append({'id': f'home-strength-v1-{level}-{variant}', 'experience': level, 'exercises': rows})
    return {
        'schema': 'bil.smart-plan.home-prescriptions.v1',
        'sourceContractId': 'bil-home-strength-general-adult-v1',
        'reviewedOn': '2026-10-23',
        'catalogSha256': hashlib.sha256((ROOT / 'artifacts/workout_media/workout_discovery_catalog_v1.json').read_bytes()).hexdigest(),
        'scope': 'General strength practice for adults who pass the existing BIL safety assessment; not injury rehabilitation or an individual clinical prescription.',
        'sources': [
            {'id': 'nhs-strength-frequency-2026', 'publisher': 'NHS', 'title': 'How to improve your strength and flexibility', 'url': 'https://www.nhs.uk/live-well/exercise/how-to-improve-strength-flexibility/', 'section': 'How often should I do strength and flexibility exercises?', 'facts': {'repetitions': [8, 12], 'sets': [2, 3]}},
            {'id': 'cdc-pcd-strength-rest-2014', 'publisher': 'CDC / Preventing Chronic Disease', 'title': 'A Strength Training Program for Primary Care Patients, Central Pennsylvania, 2012', 'url': 'https://www.cdc.gov/pcd/issues/2014/13_0403.htm', 'section': 'Introduction; DOI 10.5888/pcd11.130403', 'facts': {'restSecondsRange': [60, 180]}},
            {'id': 'acsm-home-resistance-2026', 'publisher': 'ACSM', 'title': 'ACSM Publishes Updated Resistance Training Guidelines', 'url': 'https://acsm.org/resistance-training-guidelines-update-2026/', 'facts': {'homeAndBodyweightSupported': True, 'mandatoryFailureTraining': False}},
            {'id': 'mayo-strength-recovery', 'publisher': 'Mayo Clinic', 'title': 'Strength training: Get stronger, leaner, healthier', 'url': 'https://www.mayoclinic.org/healthy-lifestyle/fitness/in-depth/strength-training/art-20046670', 'facts': {'fullRecoveryDayBetweenSameMuscleGroups': True, 'stopIfPainful': True}},
        ],
        'bilAdaptation': {
            'selection': 'Only listed released dynamic strength movements. General dosage ranges are adapted by BIL; the publishers do not endorse this exact BIL sequence.',
            'setsByExperience': {'beginner': 2, 'regular': 2, 'experienced': 3},
            'restSeconds': 120,
            'restChoiceReason': 'Two minutes is a BIL starting choice within the published 1-3 minute range; rest longer when necessary.',
            'maxSessionsPerWeek': 3,
            'progression': 'No automatic load or set increase. Review technique, comfort and completion weekly; any change requires a reviewed draft and explicit approval.',
            'environment': 'Use a clear safe floor, a stable chair for chair squats, and a fixed wall or stable counter for the named push-up variation. Do not use unstable furniture.',
            'timeBudget': 'Member availability, not measured session duration. Never shorten rests or rush technique to fit the budget.',
        },
        'sessions': sessions,
    }


def build_warmups():
    source_bytes = (ROOT / 'artifacts/workout_media/gym_training_plan_source_v1.json').read_bytes()
    source = json.loads(source_bytes)
    catalog = json.loads((ROOT / 'artifacts/workout_media/workout_discovery_catalog_v1.json').read_text(encoding='utf-8'))['items']
    gym = {row['title']: row['id'] for row in catalog if row['_release_bundle_id'] == 'gym-six-month'}
    groups = {}
    for group in ('push', 'pull', 'legs'):
        groups[group] = [{
            'title': row['movement'], 'exerciseId': gym[row['movement']],
            'dose': row['dose'],
        } for row in source['warmups'][group]]
    return {
        'schema': 'bil.smart-plan.warmups.v1',
        'gymSourceSha256': hashlib.sha256(source_bytes).hexdigest(),
        'gym': groups,
        'homeSourceUrl': 'https://www.nhs.uk/live-well/exercise/how-to-warm-up-before-exercising/',
        'homeMinimumSeconds': 360,
        'home': [
            {'title': 'March on the spot', 'titleAr': 'المشي في المكان', 'exerciseId': 'cardio-low-impact-march-in-place-steady', 'dose': '3 minutes; start gently and move your arms naturally.', 'doseAr': '3 دقائق؛ ابدأ بلطف وحرّك ذراعيك بصورة طبيعية.'},
            {'title': 'Alternating heel digs', 'titleAr': 'مدّ الكعب بالتبادل', 'exerciseId': 'cardio-low-impact-alternating-heel-dig-steady', 'dose': '60 alternating heel digs over 60 seconds; keep the supporting knee soft.', 'doseAr': '60 حركة بالتبادل خلال 60 ثانية؛ اترك الركبة الداعمة مثنية قليلًا.'},
            {'title': 'Alternating knee lifts', 'titleAr': 'رفع الركبتين بالتبادل', 'exerciseId': 'cardio-low-impact-alternating-knee-lift-steady', 'dose': '30 alternating lifts over 30 seconds, with a steady upright posture.', 'doseAr': '30 رفعة بالتبادل خلال 30 ثانية، مع ثبات الجذع بوضع مستقيم.'},
            {'title': 'Shoulder rolls while marching', 'titleAr': 'تدوير الكتفين مع المشي في المكان', 'dose': '2 sets of 10 rolls; each set has 5 forward and 5 backward rolls.', 'doseAr': 'مجموعتان من 10 دورات؛ في كل مجموعة 5 للأمام و5 للخلف.'},
            {'title': 'Shallow knee bends', 'titleAr': 'ثني خفيف للركبتين', 'dose': '10 bends, lowering no more than 10 cm; rise gently each time.', 'doseAr': '10 تكرارات، بانخفاض لا يتجاوز 10 سم؛ عُد إلى الوقوف بلطف.'},
        ],
        'mappingNote': 'Only the three exact BIL movement matches have video IDs. Shoulder rolls and shallow knee bends use the linked NHS instructions, without substituting a deeper squat or a different shoulder exercise.',
    }


if __name__ == '__main__':
    for destination, document in ((DESTINATION, build()), (WARMUPS, build_warmups())):
        content = (json.dumps(document, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
        destination.write_bytes(content)
        print(json.dumps({'path': str(destination.relative_to(ROOT)), 'sha256': hashlib.sha256(content).hexdigest()}))
