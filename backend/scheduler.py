"""APScheduler 설정 — 매일 07:00 / 22:00 (KST) 파이프라인 실행."""

from __future__ import annotations

import logging

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

from . import config
from .pipeline import run_pipeline
from .revisit_push import run_revisit_push

logger = logging.getLogger(__name__)

_scheduler: BackgroundScheduler | None = None


def start_scheduler() -> BackgroundScheduler:
    global _scheduler
    if _scheduler and _scheduler.running:
        return _scheduler

    sched = BackgroundScheduler(timezone=config.SCHEDULER_TIMEZONE)

    sched.add_job(
        lambda: run_pipeline("today"),
        CronTrigger(hour=7, minute=0, timezone=config.SCHEDULER_TIMEZONE),
        id="pipeline_today_0700",
        replace_existing=True,
        max_instances=1,
        coalesce=True,
    )
    sched.add_job(
        lambda: run_pipeline("tomorrow"),
        CronTrigger(hour=22, minute=0, timezone=config.SCHEDULER_TIMEZONE),
        id="pipeline_tomorrow_2200",
        replace_existing=True,
        max_instances=1,
        coalesce=True,
    )
    sched.add_job(
        run_revisit_push,
        CronTrigger(hour=9, minute=0, timezone=config.SCHEDULER_TIMEZONE),
        id="revisit_push_0900",
        replace_existing=True,
        max_instances=1,
        coalesce=True,
    )

    sched.start()
    _scheduler = sched
    logger.info(
        "scheduler started: 07:00 today / 22:00 tomorrow / 09:00 revisit (%s)",
        config.SCHEDULER_TIMEZONE,
    )
    return sched


def shutdown_scheduler() -> None:
    global _scheduler
    if _scheduler and _scheduler.running:
        _scheduler.shutdown(wait=False)
    _scheduler = None
