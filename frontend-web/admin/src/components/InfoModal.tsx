type InfoModalProps = {
  open: boolean;
  title: string;
  message: string;
  buttonText?: string;
  onClose: () => void;
};

export function InfoModal({
  open,
  title,
  message,
  buttonText = "OK",
  onClose,
}: InfoModalProps) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-md rounded-xl bg-white p-6 shadow-2xl">
        <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
        <p className="mt-2 text-sm text-gray-600">{message}</p>

        <div className="mt-6 flex items-center justify-end">
          <button
            onClick={onClose}
            className="rounded-md bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700"
          >
            {buttonText}
          </button>
        </div>
      </div>
    </div>
  );
}
