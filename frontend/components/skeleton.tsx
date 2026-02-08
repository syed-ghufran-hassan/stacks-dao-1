export function ShimmerSkeleton({ className = "" }: { className?: string }) {
  return (
    <div className={`relative overflow-hidden ${className}`}>
      <div className="animate-pulse bg-white/5 rounded-xl h-full w-full" />
      <div 
        className="absolute inset-0 -translate-x-full animate-shimmer bg-gradient-to-r from-transparent via-white/10 to-transparent"
        style={{
          animation: "shimmer 2s infinite"
        }}
      />
    </div>
  );
}
