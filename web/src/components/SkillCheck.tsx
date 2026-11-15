/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { useEffect, useRef, useState } from "react";
import type { ColorValue } from "@/lib/accent";
import { cn } from "@/lib/cn";
import { positionClasses } from "@/lib/position";
import { Position } from "@/types/enums";
import { sendClose, sendResolve } from "@/lib/nui";
import type { LayerProps } from "@/components/registry";

/** Picked by Lua: see client/ui/skillcheck.lua. Angles in degrees from the top, speed in degrees per ms. */
export interface SkillRound {
  areaSize: number;
  speed: number;
  start: number;
  key: string;
}

export interface SkillCheckPayload {
  rounds: SkillRound[];
  position: Position;
  color?: ColorValue;
}

export interface SkillResult {
  hit: boolean;
  /** Ms from the round start to the press, checked by Lua against the area. */
  time: number;
}

/** Pause between rounds, matching ROUND_PAUSE_MS in Lua. */
export const ROUND_PAUSE_MS = 300;

const RADIUS = 50;
const SIZE = 120;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

/** One indicator turn per round. Answers once: after the last round or the first miss. Escape closes. */
export function SkillCheck({ id, payload, exiting }: LayerProps) {
  const check = payload as SkillCheckPayload;
  const { rounds } = check;
  const [index, setIndex] = useState(0);
  const [pausing, setPausing] = useState(false);
  const results = useRef<SkillResult[]>([]);
  const startedAt = useRef(performance.now());
  const done = useRef(false);
  const round = rounds[index];

  useEffect(() => {
    if (!round || pausing || exiting) {
      return;
    }

    startedAt.current = performance.now();

    const finish = () => {
      done.current = true;
      void sendResolve(id, results.current);
    };

    const record = (result: SkillResult) => {
      results.current = [...results.current, result];

      if (!result.hit || index === rounds.length - 1) {
        finish();

        return;
      }

      setPausing(true);
      window.setTimeout(() => {
        setPausing(false);
        setIndex(index + 1);
      }, ROUND_PAUSE_MS);
    };

    const turn = 360 / round.speed;
    const missTimer = window.setTimeout(() => record({ hit: false, time: Math.round(turn) }), turn);

    const onKey = (event: KeyboardEvent) => {
      if (done.current) {
        return;
      }

      if (event.key === "Escape") {
        done.current = true;
        void sendClose(id);

        return;
      }

      if (event.repeat || event.key.length !== 1) {
        return;
      }

      window.clearTimeout(missTimer);
      window.removeEventListener("keydown", onKey);

      const time = Math.round(performance.now() - startedAt.current);
      const angle = time * round.speed;
      const hit = event.key.toLowerCase() === round.key && angle >= round.start && angle <= round.start + round.areaSize;

      record({ hit, time });
    };

    window.addEventListener("keydown", onKey);

    return () => {
      window.clearTimeout(missTimer);
      window.removeEventListener("keydown", onKey);
    };
  }, [id, index, pausing, exiting, round, rounds.length]);

  if (!round) {
    return null;
  }

  const area = (round.areaSize / 360) * CIRCUMFERENCE;

  return (
    <div className={cn(positionClasses(check.position ?? Position.Center), "p-12", exiting ? "animate-ug-fade-out" : "animate-ug-fade-in")}>
      <div className="relative" style={{ width: SIZE, height: SIZE }}>
        <svg width={SIZE} height={SIZE} viewBox={`0 0 ${SIZE} ${SIZE}`}>
          <circle cx={SIZE / 2} cy={SIZE / 2} r={RADIUS} strokeWidth={8} className="fill-card/80 stroke-white/10" />
          <circle
            key={`area-${index}`}
            cx={SIZE / 2}
            cy={SIZE / 2}
            r={RADIUS}
            strokeWidth={8}
            strokeDasharray={`${area} ${CIRCUMFERENCE}`}
            transform={`rotate(${round.start - 90} ${SIZE / 2} ${SIZE / 2})`}
            className="fill-none stroke-primary"
          />
        </svg>
        {!pausing && (
          <div
            key={`needle-${index}`}
            data-testid="needle"
            className="absolute inset-0"
            style={{ animation: `ug-skill-spin ${360 / round.speed}ms linear forwards` }}
          >
            <div className="absolute left-1/2 top-0 h-5 w-1 -translate-x-1/2 rounded-full bg-foreground" />
          </div>
        )}
        <div className="absolute inset-0 flex items-center justify-center">
          <kbd className="flex h-9 min-w-[2.25rem] items-center justify-center rounded-md bg-primary px-2 font-sans text-sm font-semibold uppercase text-primary-foreground">
            {round.key}
          </kbd>
        </div>
      </div>
      <div className="absolute mt-40 flex gap-1.5">
        {rounds.map((_, position) => (
          <div key={position} className={cn("h-1.5 w-1.5 rounded-full", position < index ? "bg-success" : position === index ? "bg-primary" : "bg-white/20")} />
        ))}
      </div>
    </div>
  );
}
