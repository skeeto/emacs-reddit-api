;;; reddit-test.el --- tests for the reddit API package

;; emacs -batch -Q -L . -l reddit-test.el -f ert-run-tests-batch

(require 'ert)
(require 'reddit)

(ert-deftest reddit-symbol-name ()
  (should (string= "alpha" (reddit-symbol-name :alpha)))
  (should (string= "beta" (reddit-symbol-name 'beta)))
  (should (string= "gam_ma" (reddit-symbol-name :gam_ma))))

(ert-deftest reddit-form-coding ()
  (let* ((data '(:alpha 1 BETA "two" :gam+ma "thr ee"))
         (encoded (reddit-form-encode data))
         (decoded (reddit-form-decode encoded)))
    (should (string= encoded "alpha=1&BETA=two&gam%2Bma=thr+ee"))
    (should (equal decoded '(:alpha "1" :BETA "two" :gam+ma "thr ee")))))

(ert-deftest reddit-url-coding ()
  (let* ((data '(:alpha 1 BETA "two" :gam+ma "thr ee"))
         (encoded (reddit-url-encode data))
         (decoded (reddit-url-decode encoded)))
    (should (string= encoded "alpha=1&BETA=two&gam%2Bma=thr%20ee"))
    (should (equal decoded '(:alpha "1" :BETA "two" :gam+ma "thr ee")))))

;;; reddit-test.el ends here
