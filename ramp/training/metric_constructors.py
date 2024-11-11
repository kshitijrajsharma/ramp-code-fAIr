#################################################################
#
# created for ramp project, August 2022
# Author: carolyn.johnston@dev.global
#
#################################################################

import functools
import logging

import tensorflow as tf
import tensorflow_addons as tfa

log = logging.getLogger()
log.addHandler(logging.NullHandler())


# Credit : https://github.com/ciupava/ramp-code-fAIr/blob/7fee0ed584fcf7d93f558550ace299c21e9d60e2/ramp/training/metric_constructors.py
class F1_Score(tf.keras.metrics.Metric):
    #  from https://stackoverflow.com/a/64477522
    def __init__(self, class_id, name="f1_score", **kwargs):
        super().__init__(name=name, **kwargs)
        self.f1 = self.add_weight(name="f1", initializer="zeros")
        self.precision_fn = tf.keras.metrics.Precision(class_id=class_id)
        self.recall_fn = tf.keras.metrics.Recall(class_id=class_id)

    def update_state(self, y_true, y_pred, sample_weight=None):
        p = self.precision_fn(y_true, y_pred)
        r = self.recall_fn(y_true, y_pred)
        self.f1.assign(tf.math.divide_no_nan(2 * (p * r), (p + r)))

    def result(self):
        return self.f1

    def reset_states(self):
        # we also need to reset the state of the precision and recall objects
        self.precision_fn.reset_states()
        self.recall_fn.reset_states()
        self.f1.assign(0)


def get_sparse_categorical_accuracy_fn(cfg):
    return tf.keras.metrics.SparseCategoricalAccuracy()


def get_categorical_accuracy_fn(cfg):
    return tf.keras.metrics.CategoricalAccuracy()


# ---
# TODO: manually changing here for OHE experiment
def get_iou_fn(cfg):
    return tf.keras.metrics.IoU(num_classes=4, target_class_ids=[0, 1], name="iou")


# ---


def get_onehotiou_fn(cfg):
    return tf.keras.metrics.OneHotIoU(
        num_classes=4, name="ohe_iou", target_class_ids=[0, 1]
    )


# ---
# TODO: manually changing here for OHE experiment
def get_precision_fn(cfg):
    return tf.keras.metrics.Precision(
        # E.g. buildings
        class_id=1,
        name="precision_1",
        # thresholds=None, top_k=None, class_id=None, name=None, dtype=None
    )


def get_recall_fn(cfg):
    return tf.keras.metrics.Recall(
        # E.g. buildings
        class_id=1,
        name="recall_1",
        # thresholds=None,top_k=None, class_id=None, name=None, dtype=None
    )


def get_f1_score_fn(cfg):
    return F1_Score(class_id=1)


def get_mse_fn(cfg):
    return tf.keras.losses.MeanSquaredError(
        # reduction=losses_utils.ReductionV2.AUTO,
        name="mean_squared_error"
    )


def get_accuracy_fn(cfg):
    return tf.keras.metrics.Accuracy()


def get_sparse_iou_fn(cfg):
    return tf.keras.metrics.IoU(sparse_y_true=True, sparse_y_pred=False)


def get_meanIoU_fn(cfg):
    return tf.keras.metrics.MeanIoU(num_classes=2)
