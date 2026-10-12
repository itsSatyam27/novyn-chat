import { useEffect, useRef, useState } from 'react';
import type { GameData } from '../../types';

export function NewGamesBoard({ game, messageId, username, onMove }: { game: GameData; messageId: string; username: string; onMove: (id: string, move: any) => void }) {
  const [value, setValue] = useState('');
  const canvas = useRef<HTMLCanvasElement>(null);
  const drawing = useRef<{ x: number; y: number } | null>(null);
  const draftStrokes = useRef(game.data.strokes || []);
  const strokes = game.data.strokes || [];
  const creator = game.data.player1 || game.createdBy;
  const isCreator = creator.toLowerCase() === username.toLowerCase();
  useEffect(() => { draftStrokes.current=strokes; const ctx=canvas.current?.getContext('2d'); if(!ctx)return; ctx.clearRect(0,0,280,150); ctx.lineWidth=4; ctx.lineCap='round'; ctx.strokeStyle='#6d5dfc'; strokes.forEach(s=>{ctx.beginPath();ctx.moveTo(s.x1,s.y1);ctx.lineTo(s.x2,s.y2);ctx.stroke();}); }, [strokes]);
  if (game.gameType === 'doodle') return <div className="novyn-mini-game"><canvas ref={canvas} width={280} height={150}
    onPointerDown={e=>{if(!isCreator)return;const r=e.currentTarget.getBoundingClientRect();drawing.current={x:(e.clientX-r.left)*280/r.width,y:(e.clientY-r.top)*150/r.height};e.currentTarget.setPointerCapture(e.pointerId);}}
    onPointerMove={e=>{if(!drawing.current||!isCreator)return;const r=e.currentTarget.getBoundingClientRect(),next={x:(e.clientX-r.left)*280/r.width,y:(e.clientY-r.top)*150/r.height};const segment={x1:drawing.current.x,y1:drawing.current.y,x2:next.x,y2:next.y};draftStrokes.current=[...draftStrokes.current,segment].slice(-800);drawing.current=next;const ctx=e.currentTarget.getContext('2d');ctx?.beginPath();ctx?.moveTo(segment.x1,segment.y1);ctx?.lineTo(next.x,next.y);ctx?.stroke();}}
    onPointerUp={()=>{if(drawing.current){drawing.current=null;onMove(messageId,{action:'draw',strokes:draftStrokes.current});}}} />
    {isCreator ? <p>Draw: <strong>{game.data.word}</strong></p> : <form onSubmit={e=>{e.preventDefault();if(value.trim()){onMove(messageId,{action:'guess',guess:value});setValue('');}}}><input value={value} onChange={e=>setValue(e.target.value)} placeholder="Guess the word"/><button>Guess</button></form>}
    {!isCreator && Boolean(game.data.guesses?.length) && <small>Guesses: {game.data.guesses?.join(', ')}</small>}
  </div>;
  if (game.gameType === 'numberclash') { const mine=isCreator?game.data.p1Number:game.data.p2Number; return <div className="novyn-mini-game"><strong>Secret target: {game.state==='finished'?game.data.target:'?'}</strong>{mine?<p>Your number is locked: {mine}</p>:<form onSubmit={e=>{e.preventDefault();onMove(messageId,{number:Number(value)});}}><input type="number" min="1" max="100" value={value} onChange={e=>setValue(e.target.value)} placeholder="1–100"/><button>Lock number</button></form>}{game.state==='finished'&&<small>{game.data.p1Number} vs {game.data.p2Number}</small>}</div>; }
  const mine=isCreator?game.data.p1Prediction:game.data.p2Prediction; return <div className="novyn-mini-game"><div className="novyn-card-value">{game.data.currentCard}</div><p>{game.state==='finished'?`Next card: ${game.data.nextCard}`:mine?'Prediction locked':'Will the next card be higher or lower?'}</p>{!mine&&<div><button onClick={()=>onMove(messageId,{prediction:'higher'})}>Higher ↑</button><button onClick={()=>onMove(messageId,{prediction:'lower'})}>Lower ↓</button></div>}</div>;
}
