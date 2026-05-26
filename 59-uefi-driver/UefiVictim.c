#include <Uefi.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiLib.h>

EFI_STATUS
EFIAPI
UefiVictimEntryPoint(
    IN EFI_HANDLE ImageHandle,
    IN EFI_SYSTEM_TABLE *SystemTable
    )
{
    UINTN signature;

    signature = 0x55454649;
    Print(L"UEFI driver victim loaded: 0x%lx\r\n", signature);
    return EFI_SUCCESS;
}
