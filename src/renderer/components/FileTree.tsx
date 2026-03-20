import React, { useState, useEffect, useCallback } from 'react';
import { useStore } from '../store';
import { usePty } from '../hooks/usePty';

interface DirEntry {
  name: string;
  isDirectory: boolean;
}

const FILE_ICONS: Record<string, { icon: string; color: string }> = {
  // JavaScript / TypeScript
  ts:    { icon: 'TS', color: '#3178c6' },
  tsx:   { icon: 'TX', color: '#3178c6' },
  js:    { icon: 'JS', color: '#f7df1e' },
  jsx:   { icon: 'JX', color: '#61dafb' },
  mjs:   { icon: 'JS', color: '#f7df1e' },
  // Web
  html:  { icon: '<>', color: '#e44d26' },
  css:   { icon: '#',  color: '#264de4' },
  scss:  { icon: '#',  color: '#cd6799' },
  svg:   { icon: 'SV', color: '#ffb13b' },
  // Data / Config
  json:  { icon: '{}', color: '#cbcb41' },
  yaml:  { icon: 'YM', color: '#cb171e' },
  yml:   { icon: 'YM', color: '#cb171e' },
  toml:  { icon: 'TM', color: '#9c4121' },
  xml:   { icon: '<>', color: '#e44d26' },
  env:   { icon: 'EV', color: '#ecd53f' },
  // Markdown / Text
  md:    { icon: 'M',  color: '#519aba' },
  txt:   { icon: 'T',  color: '#89919a' },
  // Images
  png:   { icon: 'IM', color: '#a074c4' },
  jpg:   { icon: 'IM', color: '#a074c4' },
  jpeg:  { icon: 'IM', color: '#a074c4' },
  gif:   { icon: 'IM', color: '#a074c4' },
  ico:   { icon: 'IM', color: '#a074c4' },
  webp:  { icon: 'IM', color: '#a074c4' },
  // Languages
  py:    { icon: 'PY', color: '#3776ab' },
  rb:    { icon: 'RB', color: '#cc342d' },
  go:    { icon: 'GO', color: '#00add8' },
  rs:    { icon: 'RS', color: '#dea584' },
  java:  { icon: 'JV', color: '#b07219' },
  c:     { icon: 'C',  color: '#555555' },
  cpp:   { icon: 'C+', color: '#f34b7d' },
  h:     { icon: 'H',  color: '#555555' },
  swift: { icon: 'SW', color: '#f05138' },
  // Shell / Scripts
  sh:    { icon: '$',  color: '#89e051' },
  zsh:   { icon: '$',  color: '#89e051' },
  bash:  { icon: '$',  color: '#89e051' },
  // Package / Lock
  lock:  { icon: 'LK', color: '#89919a' },
  // Other
  sql:   { icon: 'SQ', color: '#e38c00' },
  graphql: { icon: 'GQ', color: '#e535ab' },
  prisma: { icon: 'PR', color: '#2d3748' },
  dockerfile: { icon: 'DK', color: '#2496ed' },
};

const SPECIAL_FILES: Record<string, { icon: string; color: string }> = {
  'package.json':    { icon: 'NP', color: '#cb3837' },
  'tsconfig.json':   { icon: 'TS', color: '#3178c6' },
  '.gitignore':      { icon: 'GI', color: '#f05032' },
  'Dockerfile':      { icon: 'DK', color: '#2496ed' },
  'docker-compose.yml': { icon: 'DC', color: '#2496ed' },
  'Makefile':        { icon: 'MK', color: '#6d8086' },
  'LICENSE':         { icon: 'LI', color: '#d4ac0d' },
  'README.md':       { icon: 'RM', color: '#519aba' },
  'CLAUDE.md':       { icon: 'CL', color: '#d97706' },
};

function getFileIcon(name: string, isDirectory: boolean): { icon: string; color: string } {
  if (isDirectory) {
    return { icon: '', color: '' }; // handled separately with folder emoji
  }
  const special = SPECIAL_FILES[name];
  if (special) return special;
  const ext = name.includes('.') ? name.split('.').pop()!.toLowerCase() : '';
  return FILE_ICONS[ext] || { icon: 'F', color: '#89919a' };
}

interface TreeNodeProps {
  name: string;
  fullPath: string;
  isDirectory: boolean;
  depth: number;
  onFileClick: (path: string) => void;
}

function TreeNode({ name, fullPath, isDirectory, depth, onFileClick }: TreeNodeProps) {
  const [expanded, setExpanded] = useState(false);
  const [children, setChildren] = useState<DirEntry[] | null>(null);

  const toggle = useCallback(async () => {
    if (!isDirectory) {
      onFileClick(fullPath);
      return;
    }
    if (!expanded && children === null) {
      const entries = await (window as any).dispatch?.fs?.readdir(fullPath);
      setChildren(entries || []);
    }
    setExpanded(!expanded);
  }, [isDirectory, expanded, children, fullPath, onFileClick]);

  return (
    <>
      <div
        className={`d-filetree__node ${isDirectory ? 'd-filetree__node--dir' : 'd-filetree__node--file'}`}
        style={{ paddingLeft: 8 + depth * 14 }}
        onClick={toggle}
        title={fullPath}
      >
        {isDirectory ? (
          <>
            <span className="d-filetree__arrow">{expanded ? '▾' : '▸'}</span>
            <span className="d-filetree__icon d-filetree__icon--folder">{expanded ? '📂' : '📁'}</span>
          </>
        ) : (
          (() => {
            const { icon, color } = getFileIcon(name, false);
            return <>
              <span className="d-filetree__arrow" style={{ visibility: 'hidden' }}>▸</span>
              <span className="d-filetree__icon d-filetree__icon--file" style={{ color }}>
                {icon}
              </span>
            </>;
          })()
        )}
        <span className="d-filetree__name">{name}</span>
      </div>
      {expanded && children && depth < 20 && children.map((child) => (
        <TreeNode
          key={child.name}
          name={child.name}
          fullPath={`${fullPath}/${child.name}`}
          isDirectory={child.isDirectory}
          depth={depth + 1}
          onFileClick={onFileClick}
        />
      ))}
    </>
  );
}

export function FileTree() {
  const groups = useStore((s) => s.groups);
  const activeGroupId = useStore((s) => s.activeGroupId);
  const activeTerminalId = useStore((s) => s.activeTerminalId);
  const pty = usePty();
  const [entries, setEntries] = useState<DirEntry[]>([]);

  const activeGroup = groups.find((g) => g.id === activeGroupId);
  const cwd = activeGroup?.cwd;

  useEffect(() => {
    if (!cwd) { setEntries([]); return; }
    (window as any).dispatch?.fs?.readdir(cwd).then((result: DirEntry[]) => {
      setEntries(result || []);
    });
  }, [cwd]);

  const handleFileClick = useCallback((filePath: string) => {
    if (activeTerminalId) {
      // Shell-quote the path to handle spaces and special characters
      const quoted = filePath.includes(' ') || /[()&;|<>$`!"'\\#*?{}[\]~]/.test(filePath)
        ? `'${filePath.replace(/'/g, "'\\''")}'`
        : filePath;
      pty.write(activeTerminalId, quoted + ' ');
    }
  }, [activeTerminalId, pty]);

  if (!cwd) return <div className="d-filetree__empty">No project folder</div>;

  return (
    <div className="d-filetree__list">
      {entries.length === 0 ? (
        <div className="d-filetree__empty">No files</div>
      ) : (
        entries.map((entry) => (
          <TreeNode
            key={entry.name}
            name={entry.name}
            fullPath={`${cwd}/${entry.name}`}
            isDirectory={entry.isDirectory}
            depth={0}
            onFileClick={handleFileClick}
          />
        ))
      )}
    </div>
  );
}
