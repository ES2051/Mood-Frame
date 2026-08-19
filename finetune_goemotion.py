"""Fine-tune RoBERTa on GoEmotions: 28 categories, MULTI-LABEL, CLASS-WEIGHTED.

Fixes the "everything predicts neutral" problem: plain BCE loss lets the
model get away with always guessing the majority class (~33% of GoEmotions
is labeled neutral). This version computes a pos_weight per emotion from
how rare it is in the training set, and penalizes the model more for
missing rare emotions (anger, fear, grief, etc.) than for missing neutral.
"""

import numpy as np
import torch
import torch.nn as nn
from datasets import load_dataset
from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    TrainingArguments,
    Trainer,
    DataCollatorWithPadding,
)
from sklearn.metrics import f1_score

MODEL_NAME = "roberta-base"
THRESHOLD = 0.3

dataset = load_dataset("google-research-datasets/go_emotions", "simplified")

LABELS = dataset["train"].features["labels"].feature.names
NUM_LABELS = len(LABELS)
id2label = {i: l for i, l in enumerate(LABELS)}
label2id = {l: i for i, l in enumerate(LABELS)}
print(f"{NUM_LABELS} emotions:", LABELS)

tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)


def preprocess(batch):
    enc = tokenizer(batch["text"], truncation=True, max_length=128)
    onehot = np.zeros((len(batch["labels"]), NUM_LABELS), dtype=np.float32)
    for i, label_ids in enumerate(batch["labels"]):
        for lid in label_ids:
            onehot[i][lid] = 1.0
    enc["labels"] = onehot.tolist()
    return enc


tokenized = dataset.map(
    preprocess, batched=True, remove_columns=dataset["train"].column_names
)


# ---------------------------------------------------------------------------
# Compute pos_weight per label: rarer emotions get a bigger penalty when missed.
# Standard formula: pos_weight = (# negative examples) / (# positive examples)
# Capped to avoid extreme instability from ultra-rare classes (e.g. grief).
# ---------------------------------------------------------------------------

print("Computing class weights from training set label frequency...")
all_train_labels = np.array(tokenized["train"]["labels"], dtype=np.float32)
num_examples = all_train_labels.shape[0]
pos_counts = all_train_labels.sum(axis=0)  # how many examples have each label
neg_counts = num_examples - pos_counts

pos_weight = neg_counts / np.clip(pos_counts, a_min=1, a_max=None)
pos_weight = np.clip(pos_weight, a_min=None, a_max=20.0)  # cap extreme values

for label, count, weight in zip(LABELS, pos_counts, pos_weight):
    print(f"  {label:15s} count={int(count):5d}  pos_weight={weight:.2f}")

pos_weight_tensor = torch.tensor(pos_weight, dtype=torch.float32)


class FloatLabelCollator(DataCollatorWithPadding):
    """Default collator casts labels to Long. Multi-label BCE loss needs Float."""

    def __call__(self, features):
        labels = [f.pop("labels") for f in features]
        batch = super().__call__(features)
        batch["labels"] = torch.tensor(labels, dtype=torch.float32)
        return batch


collator = FloatLabelCollator(tokenizer=tokenizer)

model = AutoModelForSequenceClassification.from_pretrained(
    MODEL_NAME,
    num_labels=NUM_LABELS,
    id2label=id2label,
    label2id=label2id,
    problem_type="multi_label_classification",
)


# ---------------------------------------------------------------------------
# Custom Trainer: override compute_loss to use weighted BCE instead of the
# default (unweighted) loss that HF sets up automatically for multi-label.
# ---------------------------------------------------------------------------

class WeightedTrainer(Trainer):
    def compute_loss(self, model, inputs, return_outputs=False, num_items_in_batch=None):
        labels = inputs.pop("labels")
        outputs = model(**inputs)
        logits = outputs.logits
        loss_fct = nn.BCEWithLogitsLoss(pos_weight=pos_weight_tensor.to(logits.device))
        loss = loss_fct(logits, labels)
        return (loss, outputs) if return_outputs else loss


def compute_metrics(eval_pred):
    logits, y = eval_pred
    probs = torch.sigmoid(torch.tensor(logits)).numpy()
    preds = (probs >= THRESHOLD).astype(int)
    y = np.array(y).astype(int)
    return {
        "micro_f1": f1_score(y, preds, average="micro", zero_division=0),
        "macro_f1": f1_score(y, preds, average="macro", zero_division=0),
    }


args = TrainingArguments(
    output_dir="goemotions-weighted-ckpt",
    learning_rate=2e-5,
    per_device_train_batch_size=16,
    per_device_eval_batch_size=32,
    num_train_epochs=4,  # one extra epoch -- weighted loss converges a bit slower
    weight_decay=0.01,
    eval_strategy="epoch",
    save_strategy="epoch",
    load_best_model_at_end=True,
    metric_for_best_model="micro_f1",
    logging_steps=100,
    dataloader_pin_memory=False,
)

trainer = WeightedTrainer(
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
    trainer.save_model("emotion-model-goemotions-weighted")
    tokenizer.save_pretrained("emotion-model-goemotions-weighted")
    print("Test results:", trainer.evaluate(tokenized["test"]))
    print("\nNow set EMOTION_MODEL = './emotion-model-goemotions-weighted' in config.py")