# BFit ML

Version 1 uses the WISDM smartphone accelerometer dataset. Obtain the dataset from the official WISDM site, review its terms, and keep downloaded raw data out of source control. The trainer accepts either raw six-column records (`user, activity, timestamp, x, y, z`) or a directory containing Kaggle's WISDM `train.csv` and `test.csv` files with `acc_x,acc_y,acc_z,timestamp,Activity` columns. Both formats expect approximately 20 Hz samples.

The pipeline maps WISDM `Jogging` to `Running`; `Downstairs` and `Upstairs` are merged into `Walking`. Kaggle numeric codes are mapped as `0=Downstairs`, `1=Jogging`, `2=Sitting`, `3=Standing`, `4=Upstairs`, `5=Walking`. Kaggle files keep their supplied train/test split; raw files use a subject-held-out split. Both use 10-second windows with 50% overlap and split windows at activity changes or timestamp gaps. It reports accuracy, weighted precision/recall/F1, per-class metrics, and a confusion matrix. The serialized artifact contains the estimator and version metadata. Live inference uses the same 21 accelerometer window features; incoming app values must be normalized to the dataset's acceleration units.

```bash
python -m venv .venv
python -m pip install -r backend/requirements.txt
python ml/training/train_random_forest.py ml/data/kagglebfit
cd backend && python -m app.ml.register_model --artifact ../ml/artifacts/random_forest.joblib --metrics ../ml/artifacts/metrics.json
```

Training accuracy is not a production-quality claim. Validate across representative phone placements, hardware, and participants, then version and register the evaluated artifact before deployment.