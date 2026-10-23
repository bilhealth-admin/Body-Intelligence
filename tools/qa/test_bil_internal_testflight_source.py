import copy
import unittest
from bil_internal_testflight_source import AUTH,BASE,BRANCH,PRIOR_RUN,validate_identity,validate_prior

class InternalTestFlightGuardTest(unittest.TestCase):
    def test_exact_identity_and_unchanged_application_allowed_only_with_explicit_auth(self):
        validate_identity('a'*40,'a'*40,BRANCH,'',AUTH,[])

    def test_identity_dirty_tree_wrong_branch_missing_auth_and_app_change_rejected(self):
        good=['a'*40,'a'*40,BRANCH,'',AUTH,[]]
        for index,value in [(0,'b'*40),(1,'short'),(2,'main'),(3,' M lib/main.dart'),(4,''),(5,['lib/main.dart'])]:
            args=copy.deepcopy(good);args[index]=value
            with self.subTest(index=index),self.assertRaises(ValueError):validate_identity(*args)

    def fixture(self):
        run={'id':PRIOR_RUN,'head_sha':BASE,'head_branch':BRANCH,'workflow_id':386117761,
             'event':'workflow_dispatch','status':'completed','conclusion':'success'}
        jobs=[{'name':n,'status':'completed','conclusion':'success'} for n in
              ['Full analysis then one unsharded root suite','Supplemental source and dependency audits']]
        return run,jobs

    def test_exact_prior_real_run_and_both_jobs_required(self):
        validate_prior(*self.fixture())

    def test_stale_wrong_or_failed_prior_run_rejected(self):
        for key,value in [('id',1),('head_sha','b'*40),('head_branch','main'),('workflow_id',1),
                          ('event','push'),('status','in_progress'),('conclusion','failure')]:
            run,jobs=self.fixture();run[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_prior(run,jobs)

    def test_missing_skipped_or_failed_required_job_rejected(self):
        for kind in ('missing','skipped','failure'):
            run,jobs=self.fixture()
            if kind=='missing':jobs.pop()
            else:jobs[0]['conclusion']=kind
            with self.subTest(kind=kind),self.assertRaises(ValueError):validate_prior(run,jobs)

if __name__=='__main__':unittest.main()
