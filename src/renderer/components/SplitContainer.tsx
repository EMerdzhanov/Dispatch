import React, { useCallback, useRef, useState } from 'react';
import { useStore } from '../store';
import { TerminalPane } from './TerminalPane';
import type { SplitNode } from '../store/types';

interface SplitContainerProps {
  node: SplitNode;
  path: number[];
}

export function SplitContainer({ node, path }: SplitContainerProps) {
  const updateSplitRatio = useStore((s) => s.updateSplitRatio);

  if (node.type === 'leaf') {
    return <TerminalPane terminalId={node.terminalId} />;
  }

  const isHorizontal = node.direction === 'horizontal';
  const ratio = node.ratio;

  return (
    <div style={{ display: 'flex', flex: 1, overflow: 'hidden', flexDirection: isHorizontal ? 'row' : 'column' }}>
      <div style={{ flex: `${ratio} 1 0%`, overflow: 'hidden', display: 'flex' }}>
        <SplitContainer node={node.children[0]} path={[...path, 0]} />
      </div>
      <DragDivider
        direction={node.direction}
        onDrag={(delta) => {
          const newRatio = Math.max(0.15, Math.min(0.85, ratio + delta));
          updateSplitRatio(path, newRatio);
        }}
      />
      <div style={{ flex: `${1 - ratio} 1 0%`, overflow: 'hidden', display: 'flex' }}>
        <SplitContainer node={node.children[1]} path={[...path, 1]} />
      </div>
    </div>
  );
}

function DragDivider({ direction, onDrag }: { direction: 'horizontal' | 'vertical'; onDrag: (delta: number) => void }) {
  const divRef = useRef<HTMLDivElement>(null);
  const [dragging, setDragging] = useState(false);

  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    setDragging(true);
    const startPos = direction === 'horizontal' ? e.clientX : e.clientY;
    const parentSize = direction === 'horizontal'
      ? divRef.current?.parentElement?.clientWidth ?? 1
      : divRef.current?.parentElement?.clientHeight ?? 1;

    const handleMouseMove = (me: MouseEvent) => {
      const currentPos = direction === 'horizontal' ? me.clientX : me.clientY;
      const delta = (currentPos - startPos) / parentSize;
      onDrag(delta);
    };

    const handleMouseUp = () => {
      setDragging(false);
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };

    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
  }, [direction, onDrag]);

  return (
    <div
      ref={divRef}
      style={{
        flexShrink: 0,
        width: direction === 'horizontal' ? 4 : undefined,
        height: direction === 'vertical' ? 4 : undefined,
        cursor: direction === 'horizontal' ? 'col-resize' : 'row-resize',
        backgroundColor: dragging ? 'var(--accent-primary)' : 'var(--border-default)',
      }}
      onMouseDown={handleMouseDown}
    />
  );
}
