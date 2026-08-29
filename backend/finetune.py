"""
Fine-tune a transformer for emotion detection.
-----------------------------------------------
This is where your accuracy actually comes from. Out of the box it trains on
the public `dair-ai/emotion` dataset (6 emotions). To maximize accuracy on YOUR
inputs, replace it with your own labeled CSV that looks like your real traffic
(see the load_dataset call below).

Run:
    pip install -r requirements.txt
    python finetune.py

Outputs a ready-to-serve model folder: ./emotion-model-final
Point app.py's MODEL_NAME at that folder to serve it.
"""

import numpy as np
from datasets import load_dataset
from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    TrainingArguments,
    Trainer,
    DataCollatorWithPadding,
)
import evaluate

# roberta-base is a strong, low-friction default.
# For higher accuracy try "microsoft/deberta-v3-base" or "roberta-large"
# (slower; deberta-v3 also needs the `sentencepiece` package).
MODEL_NAME = "roberta-base"

# --- Load data -------------------------------------------------------------
# Public dataset (6 emotions): sadness, joy, love, anger, fear, surprise.
dataset = load_dataset("dair-ai/emotion")
# To use your own data instead, comment the line above and use:
# dataset = load_dataset("csv", data_files={
#     "train": "train.csv", "validation": "val.csv", "test": "test.csv"
# })
# Your CSV needs two columns: "text" and "label" (label as an integer id).

labels = dataset["train"].features["label"].names
num_labels = len(labels)
id2label = {i: name for i, name in enumerate(labels)}
label2id = {name: i for i, name in enumerate(labels)}

# --- Tokenize --------------------------------------------------------------
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)


def tokenize(batch):
    return tokenizer(batch["text"], truncation=True, max_length=128)


tokenized = dataset.map(tokenize, batched=True)
collator = DataCollatorWithPadding(tokenizer=tokenizer)

model = AutoModelForSequenceClassification.from_pretrained(
    MODEL_NAME, num_labels=num_labels, id2label=id2label, label2id=label2id
)

# --- Metrics: report macro-F1, not just accuracy ---------------------------
f1 = evaluate.load("f1")
accuracy = evaluate.load("accuracy")


def compute_metrics(eval_pred):
    logits, y = eval_pred
    preds = np.argmax(logits, axis=-1)
    return {
        "accuracy": accuracy.compute(predictions=preds, references=y)["accuracy"],
        "macro_f1": f1.compute(predictions=preds, references=y, average="macro")["f1"],
    }


# --- Train -----------------------------------------------------------------
args = TrainingArguments(
    output_dir="emotion-model",
    learning_rate=2e-5,
    per_device_train_batch_size=16,
    per_device_eval_batch_size=32,
    num_train_epochs=4,
    weight_decay=0.01,
    eval_strategy="epoch",      # older transformers: evaluation_strategy="epoch"
    save_strategy="epoch",
    load_best_model_at_end=True,
    metric_for_best_model="macro_f1",
    logging_steps=50,
)

trainer = Trainer(
    model=model,
    args=args,
    train_dataset=tokenized["train"],
    eval_dataset=tokenized["validation"],
    tokenizer=tokenizer,
    data_collator=collator,
    compute_metrics=compute_metrics,
)

if __name__ == "__main__":
    trainer.train()
    trainer.save_model("emotion-model-final")
    tokenizer.save_pretrained("emotion-model-final")
    print("Test set results:", trainer.evaluate(tokenized["test"]))